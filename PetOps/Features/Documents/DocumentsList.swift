import SwiftUI
import CoreData

struct DocumentsList: View {
    let pet: Pet

    @FetchRequest private var docs: FetchedResults<Document>

    init(pet: Pet) {
        self.pet = pet
        _docs = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Document.createdAt, ascending: false)],
            predicate: NSPredicate(format: "pet == %@", pet),
            animation: .default
        )
    }

    var body: some View {
        List {
            if docs.isEmpty {
                ContentUnavailableView("No documents yet", systemImage: "doc.text", description: Text("Import a PDF or image."))
            } else {
                ForEach(docs) { d in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(d.type ?? "other").font(.caption).foregroundStyle(.secondary)
                        Text((d.filePath ?? "").split(separator: "/").last.map(String.init) ?? "Document")
                            .font(.headline)
                        if let dt = d.createdAt {
                            Text(dt, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
