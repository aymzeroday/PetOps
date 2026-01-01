import SwiftUI
import CoreData

struct DocumentsList: View {
    @Environment(\.managedObjectContext) private var viewContext

    let pet: Pet
    let query: String

    @FetchRequest private var docs: FetchedResults<Document>

    init(pet: Pet, query: String) {
        self.pet = pet
        self.query = query

        let base = NSPredicate(format: "pet == %@", pet)

        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _docs = FetchRequest(
                sortDescriptors: [NSSortDescriptor(keyPath: \Document.createdAt, ascending: false)],
                predicate: base,
                animation: .default
            )
        } else {
            let q = query as NSString
            let p = NSCompoundPredicate(andPredicateWithSubpredicates: [
                base,
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "ocrText CONTAINS[c] %@", q),
                    NSPredicate(format: "type CONTAINS[c] %@", q),
                    NSPredicate(format: "filePath CONTAINS[c] %@", q)
                ])
            ])

            _docs = FetchRequest(
                sortDescriptors: [NSSortDescriptor(keyPath: \Document.createdAt, ascending: false)],
                predicate: p,
                animation: .default
            )
        }
    }

    var body: some View {
        List {
            if docs.isEmpty {
                ContentUnavailableView("No documents", systemImage: "doc.text", description: Text("Scan or import a file."))
            } else {
                ForEach(docs) { d in
                    NavigationLink {
                        DocumentDetailView(document: d)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text((d.type ?? "other").uppercased())
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(URL(fileURLWithPath: d.filePath ?? "").lastPathComponent)
                                .font(.headline)

                            if let dt = d.createdAt {
                                Text(dt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: delete)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for idx in offsets {
            let d = docs[idx]
            if let path = d.filePath {
                FileStore.shared.delete(path: path)
            }
            viewContext.delete(d)
        }
        try? viewContext.save()
    }
}
