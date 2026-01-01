import SwiftUI
import CoreData

struct EventRemindersView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let event: TimelineEvent

    @FetchRequest private var rules: FetchedResults<ReminderRule>

    @State private var showingEditor = false
    @State private var editing: ReminderRule?

    init(event: TimelineEvent) {
        self.event = event
        _rules = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \ReminderRule.createdAt, ascending: false)],
            predicate: NSPredicate(format: "event == %@", event),
            animation: .default
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Add Reminder") {
                editing = nil
                showingEditor = true
            }

            if rules.isEmpty {
                Text("No reminders for this event.").foregroundStyle(.secondary)
            } else {
                ForEach(rules) { r in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(r.title ?? "Reminder").font(.headline)
                            Text(summary(r)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { r.enabled },
                            set: { v in
                                r.enabled = v
                                try? viewContext.save()
                                Task { try? await NotificationManager.shared.schedule(rule: r) }
                            }
                        ))
                        .labelsHidden()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editing = r
                        showingEditor = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            ReminderRuleEditorView(pet: event.pet!, event: event, rule: editing)
        }
    }

    private func summary(_ r: ReminderRule) -> String {
        guard let json = r.scheduleJSON, let s = try? ReminderSchedule.decode(json: json) else { return "Schedule not set" }
        return s.summaryText()
    }
}
