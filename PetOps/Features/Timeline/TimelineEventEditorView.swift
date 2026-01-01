import SwiftUI
import CoreData

struct TimelineEventEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let pet: Pet

    @State private var type: String = "note"
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var eventDate: Date = Date()

    private let typeOptions = ["note", "symptom", "visit", "vaccine", "med", "lab", "procedure"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    Picker("Type", selection: $type) {
                        ForEach(typeOptions, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $eventDate)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Add Event")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let ev = TimelineEvent(context: viewContext)
        ev.id = UUID()
        ev.type = type
        ev.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        ev.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ev.eventDate = eventDate
        ev.createdAt = Date()
        ev.pet = pet

        try? viewContext.save()
        dismiss()
    }
}
