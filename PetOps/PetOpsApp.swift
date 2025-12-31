//
//  PetOpsApp.swift
//  PetOps
//
//  Created by Ahmad Raafat on 31/12/2025.
//

import SwiftUI
import CoreData

@main
struct PetOpsApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
