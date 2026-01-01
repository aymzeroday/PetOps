import SwiftUI
import CoreData

struct EventAttachmentsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let event: TimelineEvent

    @FetchRequest private var attachments: FetchedResults<Attachment>

    @State private var previewPath: String?

    init(event: TimelineEvent) {
        self.event = event
        _attachments = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Attachment.createdAt, ascending: false)],
            predicate: NSPredicate(format: "event == %@", event),
            animation: .default
        )
    }

    var body: some View {
        if attachments.isEmpty {
            Text("No attachments yet.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(attachments) { a in
                HStack {
                    Text((a.kind ?? "file").uppercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(filename(a.filePath))
                        .lineLimit(1)

                    Spacer()

                    Button {
                        previewPath = a.filePath
                    } label: {
                        Image(systemName: "eye")
                    }

                    Button(role: .destructive) {
                        delete(a)
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .sheet(item: Binding(
                get: { previewPath.map { PreviewPath(path: $0) } },
                set: { previewPath = $0?.path }
            )) { item in
                AttachmentPreviewView(path: item.path)
            }
        }
    }

    private func delete(_ a: Attachment) {
        if let p = a.filePath { FileStore.shared.delete(path: p) }
        viewContext.delete(a)
        try? viewContext.save()
    }

    private func filename(_ path: String?) -> String {
        guard let path else { return "Attachment" }
        return URL(fileURLWithPath: path).lastPathComponent
    }
}

struct PreviewPath: Identifiable {
    let id = UUID()
    let path: String
}
