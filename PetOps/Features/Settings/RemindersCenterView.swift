import SwiftUI
import CoreData

struct RemindersCenterView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Pet.createdAt, ascending: true)])
    private var pets: FetchedResults<Pet>

    private var selectedPet: Pet? {
        guard let id = appState.selectedPetID else { return nil }
        return pets.first(where: { $0.id == id })
    }

    var body: some View {
        Group {
            if pets.isEmpty {
                ContentUnavailableView("No pets", systemImage: "pawprint")
            } else if selectedPet == nil {
                ContentUnavailableView("No active pet", systemImage: "checkmark.circle", description: Text("Select a pet in Pets."))
            } else {
                ReminderRulesListView(pet: selectedPet!)
            }
        }
        .navigationTitle("Reminders")
    }
}
