import SwiftUI
import CoreData

struct DocumentsList: View {
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
                            Text(d.type ?? "other").font(.caption).foregroundStyle(.secondary)
                            Text(URL(fileURLWithPath: d.filePath ?? "").lastPathComponent)
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
}
