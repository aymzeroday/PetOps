import SwiftUI
import CoreData

struct PetsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState

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
                            appState.selectedPetID = pet.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pet.name ?? "Unnamed").font(.headline)
                                    Text(pet.species ?? "").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if appState.selectedPetID == pet.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .contextMenu {
                            Button("Edit") {
                                editingPet = pet
                                showingEditor = true
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
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingEditor) {
                PetEditorView(pet: editingPet)
            }
        }
    }

    private func deletePets(offsets: IndexSet) {
        let deleting = offsets.map { pets[$0] }
        deleting.forEach(viewContext.delete)

        if deleting.contains(where: { $0.id == appState.selectedPetID }) {
            appState.selectedPetID = nil
        }

        try? viewContext.save()
    }
}
