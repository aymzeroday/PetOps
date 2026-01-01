import SwiftUI
import CoreData

struct ExpensesListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let pet: Pet
    @FetchRequest private var expenses: FetchedResults<Expense>

    @State private var showingEditor = false
    @State private var editing: Expense?

    init(pet: Pet) {
        self.pet = pet
        _expenses = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Expense.expenseDate, ascending: false)],
            predicate: NSPredicate(format: "pet == %@", pet),
            animation: .default
        )
    }

    var body: some View {
        List {
            if expenses.isEmpty {
                ContentUnavailableView("No expenses yet", systemImage: "creditcard", description: Text("Add your first expense."))
            } else {
                ForEach(expenses) { e in
                    Button {
                        editing = e
                        showingEditor = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(e.category ?? "Uncategorized").font(.headline)
                                HStack(spacing: 8) {
                                    if let v = e.vendor, !v.isEmpty {
                                        Text(v).font(.caption).foregroundStyle(.secondary)
                                    }
                                    if let d = e.expenseDate {
                                        Text(d, style: .date).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            Text(amountText(e))
                                .font(.headline)
                        }
                    }
                }
                .onDelete(perform: deleteExpenses)
            }
        }
        .navigationTitle(pet.name ?? "Costs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editing = nil
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            ExpenseEditorView(pet: pet, expense: editing)
        }
    }

    private func amountText(_ e: Expense) -> String {
        let cur = (e.currency ?? "KWD").uppercased()
        let n = e.amount as Decimal? ?? 0
        return "\(cur) \(NSDecimalNumber(decimal: n).stringValue)"
    }

    private func deleteExpenses(offsets: IndexSet) {
        offsets.map { expenses[$0] }.forEach(viewContext.delete)
        try? viewContext.save()
    }
}
