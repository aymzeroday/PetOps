import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct DocumentsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Pet.createdAt, ascending: true)])
    private var pets: FetchedResults<Pet>

    @State private var showingImporter = false
    @State private var errorMessage: String?

    private var selectedPet: Pet? {
        guard let id = appState.selectedPetID else { return nil }
        return pets.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            if pets.isEmpty {
                ContentUnavailableView("No pets", systemImage: "pawprint", description: Text("Create a pet first."))
                    .navigationTitle("Documents")
            } else if selectedPet == nil {
                ContentUnavailableView("No active pet", systemImage: "checkmark.circle", description: Text("Select a pet in Pets."))
                    .navigationTitle("Documents")
            } else {
                DocumentsList(pet: selectedPet!)
                    .navigationTitle("Documents")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingImporter = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Import failed", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        guard let pet = selectedPet else { return }
        do {
            let url = try result.get().first!

            let gotAccess = url.startAccessingSecurityScopedResource()
            defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.isEmpty ? "bin" : url.pathExtension

            let savedPath = try FileStore.shared.save(data: data, ext: ext)

            let doc = Document(context: viewContext)
            doc.id = UUID()
            doc.type = "other"
            doc.filePath = savedPath
            doc.createdAt = Date()
            doc.pet = pet

            try viewContext.save()
        } catch {
            errorMessage = "\(error)"
        }
    }
}
