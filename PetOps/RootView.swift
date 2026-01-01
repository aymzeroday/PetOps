import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            PetsView()
                .tabItem { Label("Pets", systemImage: "pawprint") }

            TimelineView()
                .tabItem { Label("Timeline", systemImage: "clock") }

            DocumentsView()
                .tabItem { Label("Documents", systemImage: "doc.text") }

            CostsView()
                .tabItem { Label("Costs", systemImage: "creditcard") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
