import Foundation
import Combine

final class AppState: ObservableObject {
    private let key = "selectedPetID"

    @Published var selectedPetID: UUID? {
        didSet { save() }
    }

    init() {
        load()
    }

    private func load() {
        guard let s = UserDefaults.standard.string(forKey: key),
              let id = UUID(uuidString: s)
        else {
            selectedPetID = nil
            return
        }
        selectedPetID = id
    }

    private func save() {
        if let id = selectedPetID {
            UserDefaults.standard.set(id.uuidString, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
