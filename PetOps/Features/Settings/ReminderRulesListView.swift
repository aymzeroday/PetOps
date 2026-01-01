import SwiftUI
import CoreData

struct ReminderRulesListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let pet: Pet

    @FetchRequest private var rules: FetchedResults<ReminderRule>

    @State private var showingEditor = false
    @State private var editing: ReminderRule?

    init(pet: Pet) {
        self.pet = pet
        _rules = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \ReminderRule.createdAt, ascending: false)],
            predicate: NSPredicate(format: "pet == %@", pet),
            animation: .default
        )
    }

    var body: some View {
        List {
            if rules.isEmpty {
                ContentUnavailableView("No reminders yet", systemImage: "bell", description: Text("Create your first reminder."))
            } else {
                ForEach(rules) { r in
                    Button {
                        editing = r
                        showingEditor = true
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.title ?? "Reminder").font(.headline)
                                Text(scheduleSummary(r)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { r.enabled },
                                set: { newValue in
                                    r.enabled = newValue
                                    try? viewContext.save()
                                    Task { try? await NotificationManager.shared.schedule(rule: r) }
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editing = nil
                    showingEditor = true
                } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingEditor) {
            ReminderRuleEditorView(pet: pet, event: nil, rule: editing)
        }
    }

    private func scheduleSummary(_ r: ReminderRule) -> String {
        guard let json = r.scheduleJSON, let s = try? ReminderSchedule.decode(json: json) else { return "Schedule not set" }
        return s.summaryText()
    }

    private func delete(offsets: IndexSet) {
        offsets.map { rules[$0] }.forEach { r in
            Task { await NotificationManager.shared.cancel(ruleID: r.idString) }
            viewContext.delete(r)
        }
        try? viewContext.save()
    }
}
