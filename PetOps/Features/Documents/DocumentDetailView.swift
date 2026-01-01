import SwiftUI
import CoreData

struct DocumentDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let document: Document

    private var url: URL? {
        guard let p = document.filePath else { return nil }
        return FileStore.shared.fileURL(path: p)
    }

    var body: some View {
        Group {
            if let url {
                QuickLookPreview(url: url)
                    .ignoresSafeArea()
            } else {
                ContentUnavailableView("Missing file", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(document.type ?? "Document")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: url)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { delete() } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }

    private func delete() {
        if let p = document.filePath {
            FileStore.shared.delete(path: p)
        }
        viewContext.delete(document)
        try? viewContext.save()
        dismiss()
    }
}
