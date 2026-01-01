import SwiftUI
import CoreData

struct TimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pet.createdAt, ascending: true)],
        animation: .default
    )
    private var pets: FetchedResults<Pet>

    var selectedPet: Pet? {
        guard let id = appState.selectedPetID else { return nil }
        return pets.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            if pets.isEmpty {
                ContentUnavailableView("No pets", systemImage: "pawprint", description: Text("Create a pet first."))
                    .navigationTitle("Timeline")
            } else if selectedPet == nil {
                ContentUnavailableView("No active pet", systemImage: "checkmark.circle", description: Text("Select a pet in Pets."))
                    .navigationTitle("Timeline")
            } else {
                TimelineEventsList(pet: selectedPet!)
            }
        }
    }
}
