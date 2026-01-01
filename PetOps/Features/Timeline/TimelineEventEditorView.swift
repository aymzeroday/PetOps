import SwiftUI
import CoreData

struct TimelineEventEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let pet: Pet
    let event: TimelineEvent?

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
                    TextEditor(text: $notes).frame(minHeight: 120)
                }
            }
            .navigationTitle(event == nil ? "Add Event" : "Edit Event")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        guard let e = event else { return }
        type = e.type ?? "note"
        title = e.title ?? ""
        notes = e.notes ?? ""
        eventDate = e.eventDate ?? Date()
    }

    private func save() {
        let target = event ?? TimelineEvent(context: viewContext)
        if target.id == nil { target.id = UUID() }
        if target.createdAt == nil { target.createdAt = Date() }

        target.type = type
        target.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.eventDate = eventDate
        target.pet = pet

        try? viewContext.save()
        dismiss()
    }
}
