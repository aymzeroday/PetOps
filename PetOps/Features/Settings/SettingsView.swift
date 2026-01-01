import SwiftUI
import UserNotifications
import UIKit

struct SettingsView: View {
    @State private var statusText: String = "Unknown"
    @State private var denied = false

    var body: some View {
        NavigationStack {
            List {
                Section("Notifications") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(statusText).foregroundStyle(.secondary)
                    }

                    Button("Request Permission") {
                        Task {
                            let ok = (try? await NotificationManager.shared.requestAuthorizationIfNeeded()) ?? false
                            let status = await NotificationManager.shared.authorizationStatus()

                            await MainActor.run {
                                statusText = mapStatus(status)
                                denied = (!ok && status == .denied) || status == .denied
                            }
                        }
                    }

                    if denied {
                        Button("Open iOS Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }

                Section("Data") {
                    NavigationLink("Reminders") {
                        RemindersCenterView()
                    }
                }
            }
            .navigationTitle("Settings")
            .task { await refresh() }
        }
    }

    private func refresh() async {
        let s = await NotificationManager.shared.authorizationStatus()
        await MainActor.run {
            statusText = mapStatus(s)
            denied = (s == .denied)
        }
    }

    private func mapStatus(_ s: UNAuthorizationStatus) -> String {
        switch s {
        case .authorized: "Authorized"
        case .denied: "Denied"
        case .notDetermined: "Not Determined"
        case .provisional: "Provisional"
        case .ephemeral: "Ephemeral"
        @unknown default: "Unknown"
        }
    }
}
