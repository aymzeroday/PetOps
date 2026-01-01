import SwiftUI
import CoreData

struct PetsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pet.createdAt, ascending: true)],
        animation: .default
    )
    private var pets: FetchedResults<Pet>

    var body: some View {
        NavigationStack {
            List {
                ForEach(pets) { pet in
                    Text(pet.name ?? "Unnamed")
                }
                .onDelete(perform: deletePets)
            }
            .navigationTitle("Pets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", action: addPet)
                }
            }
        }
    }

    private func addPet() {
        let p = Pet(context: viewContext)
        p.id = UUID()
        p.name = "My Cat"
        p.species = "Cat"
        p.createdAt = Date()

        try? viewContext.save()
    }

    private func deletePets(offsets: IndexSet) {
        offsets.map { pets[$0] }.forEach(viewContext.delete)
        try? viewContext.save()
    }
}
