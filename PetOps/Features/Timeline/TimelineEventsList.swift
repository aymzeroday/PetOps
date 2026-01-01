import SwiftUI
import CoreData

struct TimelineEventsList: View {
    @Environment(\.managedObjectContext) private var viewContext

    let pet: Pet

    @FetchRequest private var events: FetchedResults<TimelineEvent>

    @State private var showingEditor = false
    @State private var editingEvent: TimelineEvent?

    init(pet: Pet) {
        self.pet = pet
        _events = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TimelineEvent.eventDate, ascending: false)],
            predicate: NSPredicate(format: "pet == %@", pet),
            animation: .default
        )
    }

    var body: some View {
        List {
            if events.isEmpty {
                ContentUnavailableView("No events yet", systemImage: "clock", description: Text("Add your first event."))
            } else {
                ForEach(events) { ev in
                    NavigationLink {
                        TimelineEventDetailView(event: ev)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ev.title ?? "Untitled")
                                .font(.headline)

                            HStack(spacing: 8) {
                                Text((ev.type ?? "").uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(ev.eventDate ?? .now, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let notes = ev.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .contextMenu {
                        Button("Edit") {
                            editingEvent = ev
                            showingEditor = true
                        }

                        Button("Delete", role: .destructive) {
                            deleteEvent(ev)
                        }
                    }
                }
                .onDelete(perform: deleteEvents)
            }
        }
        .navigationTitle(pet.name ?? "Timeline")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingEvent = nil
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            TimelineEventEditorView(pet: pet, event: editingEvent)
        }
    }

    private func deleteEvents(offsets: IndexSet) {
        offsets.map { events[$0] }.forEach(deleteEvent)
        try? viewContext.save()
    }

    private func deleteEvent(_ ev: TimelineEvent) {
        // Delete attachment files if you added Attachment entity
        if let set = ev.attachments as? Set<Attachment> {
            for a in set {
                if let p = a.filePath { FileStore.shared.delete(path: p) }
            }
        }
        viewContext.delete(ev)
    }
}
