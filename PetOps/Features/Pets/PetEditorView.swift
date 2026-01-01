import SwiftUI
import CoreData

struct PetEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let pet: Pet?

    @State private var name: String = ""
    @State private var species: String = "Cat"
    @State private var birthDate: Date = Date()

    private let speciesOptions = ["Cat", "Dog", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name", text: $name)

                    Picker("Species", selection: $species) {
                        ForEach(speciesOptions, id: \.self) { Text($0) }
                    }

                    DatePicker("Birth date", selection: $birthDate, displayedComponents: .date)
                }
            }
            .navigationTitle(pet == nil ? "Add Pet" : "Edit Pet")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let pet {
                    name = pet.name ?? ""
                    species = pet.species ?? "Cat"
                    birthDate = pet.birthDate ?? Date()
                }
            }
        }
    }

    private func save() {
        let target = pet ?? Pet(context: viewContext)
        if target.id == nil { target.id = UUID() }
        if target.createdAt == nil { target.createdAt = Date() }

        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.species = species
        target.birthDate = birthDate

        try? viewContext.save()
        dismiss()
    }
}
