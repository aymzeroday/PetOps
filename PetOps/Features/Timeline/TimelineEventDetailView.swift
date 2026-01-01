import SwiftUI
import CoreData
import PhotosUI

struct TimelineEventDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let event: TimelineEvent

    @State private var showingEditor = false
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Event") {
                LabeledContent("Type", value: (event.type ?? "").uppercased())
                if let d = event.eventDate {
                    LabeledContent("Date") { Text(d, style: .date) }
                }
                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                }
            }

            Section("Attachments") {
                EventAttachmentsView(event: event)
            }
        }
        .navigationTitle(event.title ?? "Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    Image(systemName: "paperclip")
                }

                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "pencil")
                }

                Button(role: .destructive) {
                    deleteEvent()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            TimelineEventEditorView(pet: event.pet!, event: event)
        }
        .onChange(of: pickedPhoto) { _, newItem in
            guard let newItem else { return }
            Task { await addPhoto(item: newItem) }
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func addPhoto(item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let path = try FileStore.shared.save(data: data, ext: "jpg")

            let a = Attachment(context: viewContext)
            a.id = UUID()
            a.kind = "photo"
            a.filePath = path
            a.createdAt = Date()
            a.event = event

            try viewContext.save()
        } catch {
            errorMessage = "\(error)"
        }
    }

    private func deleteEvent() {
        // delete attachment files too
        if let set = event.attachments as? Set<Attachment> {
            for a in set {
                if let p = a.filePath { FileStore.shared.delete(path: p) }
            }
        }
        viewContext.delete(event)
        try? viewContext.save()
        dismiss()
    }
}
