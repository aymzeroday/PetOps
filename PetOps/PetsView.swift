import SwiftUI
import CoreData

struct PetsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pet.createdAt, ascending: true)],
        animation: .default
    )
    private var pets: FetchedResults<Pet>

    @State private var showingEditor = false
    @State private var editingPet: Pet?

    var body: some View {
        NavigationStack {
            List {
                if pets.isEmpty {
                    ContentUnavailableView("No pets yet", systemImage: "pawprint", description: Text("Add your first pet."))
                } else {
                    ForEach(pets) { pet in
                        Button {
                            editingPet = pet
                            showingEditor = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pet.name ?? "Unnamed")
                                    .font(.headline)
                                Text(pet.species ?? "")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deletePets)
                }
            }
            .navigationTitle("Pets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingPet = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                PetEditorView(pet: editingPet)
            }
        }
    }

    private func deletePets(offsets: IndexSet) {
        offsets.map { pets[$0] }.forEach(viewContext.delete)
        try? viewContext.save()
    }
}
