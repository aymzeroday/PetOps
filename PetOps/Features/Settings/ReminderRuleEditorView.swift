import SwiftUI
import CoreData

struct ReminderRuleEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let pet: Pet
    let event: TimelineEvent?
    let rule: ReminderRule?

    @State private var title: String = ""
    @State private var message: String = ""
    @State private var enabled: Bool = true

    @State private var kind: ReminderKind = .once
    @State private var onceDate: Date = Date().addingTimeInterval(3600)

    @State private var hour: Int = Calendar.current.component(.hour, from: Date())
    @State private var minute: Int = Calendar.current.component(.minute, from: Date())
    @State private var weekday: Int = 2

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder") {
                    TextField("Title", text: $title)
                    TextField("Body (optional)", text: $message)
                    Toggle("Enabled", isOn: $enabled)
                }

                Section("Schedule") {
                    Picker("Type", selection: $kind) {
                        Text("Once").tag(ReminderKind.once)
                        Text("Daily").tag(ReminderKind.daily)
                        Text("Weekly").tag(ReminderKind.weekly)
                    }

                    switch kind {
                    case .once:
                        DatePicker("When", selection: $onceDate, displayedComponents: [.date, .hourAndMinute])

                    case .daily:
                        timePickers

                    case .weekly:
                        Picker("Day", selection: $weekday) {
                            ForEach(1...7, id: \.self) { d in
                                Text(Calendar.current.weekdaySymbols[d-1]).tag(d)
                            }
                        }
                        timePickers
                    }
                }
            }
            .navigationTitle(rule == nil ? "New Reminder" : "Edit Reminder")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { Task { await save() } }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { load() }
        }
    }

    private var timePickers: some View {
        HStack {
            Stepper("Hour: \(hour)", value: $hour, in: 0...23)
        }
        .padding(.vertical, 4)

        return HStack {
            Stepper("Minute: \(minute)", value: $minute, in: 0...59, step: 5)
        }
        .padding(.vertical, 4)
    }

    private func load() {
        if let r = rule {
            title = r.title ?? ""
            message = r.body ?? ""
            enabled = r.enabled

            if let json = r.scheduleJSON, let s = try? ReminderSchedule.decode(json: json) {
                kind = s.kind
                if let fd = s.fireDate { onceDate = fd }
                hour = s.hour
                minute = s.minute
                weekday = s.weekday ?? 2
            }
        } else if let event {
            title = event.title ?? "Reminder"
        } else {
            title = "Reminder"
        }
    }

    private func buildSchedule() -> ReminderSchedule {
        switch kind {
        case .once:
            return ReminderSchedule(kind: .once, fireDate: onceDate, hour: hour, minute: minute, weekday: nil)
        case .daily:
            return ReminderSchedule(kind: .daily, fireDate: nil, hour: hour, minute: minute, weekday: nil)
        case .weekly:
            return ReminderSchedule(kind: .weekly, fireDate: nil, hour: hour, minute: minute, weekday: weekday)
        }
    }

    private func save() async {
        _ = (try? await NotificationManager.shared.requestAuthorizationIfNeeded()) ?? false

        let target = rule ?? ReminderRule(context: viewContext)
        if target.id == nil { target.id = UUID() }
        if target.createdAt == nil { target.createdAt = Date() }

        target.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        target.body = message.trimmingCharacters(in: .whitespacesAndNewlines)
        target.enabled = enabled
        target.pet = pet
        target.event = event

        let schedule = buildSchedule()
        target.scheduleJSON = (try? schedule.encode()) ?? ""

        try? viewContext.save()
        try? await NotificationManager.shared.schedule(rule: target)
        dismiss()
    }
}
