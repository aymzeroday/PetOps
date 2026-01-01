// PetOps/Features/Costs/ExpenseListView.swift

import SwiftUI
import CoreData

struct ExpenseListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Pet.createdAt, ascending: true)])
    private var pets: FetchedResults<Pet>

    @State private var searchText: String = ""

    private var selectedPet: Pet? {
        guard let id = appState.selectedPetID else { return nil }
        return pets.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            if pets.isEmpty {
                ContentUnavailableView("No pets", systemImage: "pawprint", description: Text("Create a pet first."))
                    .navigationTitle("Costs")
            } else if selectedPet == nil {
                ContentUnavailableView("No active pet", systemImage: "checkmark.circle", description: Text("Select a pet in Pets."))
                    .navigationTitle("Costs")
            } else {
                ExpensesForPetList(pet: selectedPet!, query: searchText)
                    .id(searchText)
                    .navigationTitle("Costs")
                    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            }
        }
    }
}

private struct ExpensesForPetList: View {
    @Environment(\.managedObjectContext) private var viewContext

    let pet: Pet
    let query: String

    @FetchRequest private var expenses: FetchedResults<Expense>

    init(pet: Pet, query: String) {
        self.pet = pet
        self.query = query

        let base = NSPredicate(format: "pet == %@", pet)

        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _expenses = FetchRequest(
                sortDescriptors: [NSSortDescriptor(keyPath: \Expense.expenseDate, ascending: false)],
                predicate: base,
                animation: .default
            )
        } else {
            let q = query as NSString
            let p = NSCompoundPredicate(andPredicateWithSubpredicates: [
                base,
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "vendor CONTAINS[c] %@", q),
                    NSPredicate(format: "category CONTAINS[c] %@", q),
                    NSPredicate(format: "currency CONTAINS[c] %@", q)
                ])
            ])

            _expenses = FetchRequest(
                sortDescriptors: [NSSortDescriptor(keyPath: \Expense.expenseDate, ascending: false)],
                predicate: p,
                animation: .default
            )
        }
    }

    var body: some View {
        List {
            if expenses.isEmpty {
                ContentUnavailableView("No costs", systemImage: "creditcard", description: Text("Scan a receipt in Documents to auto-create."))
            } else {
                ForEach(expenses) { e in
                    NavigationLink {
                        ExpenseEditorView(expense: e)
                    } label: {
                        row(e)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ExpenseEditorView(expense: createExpense())
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func row(_ e: Expense) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text((e.vendor ?? "").isEmpty ? "Expense" : (e.vendor ?? "Expense"))
                .font(.headline)

            HStack {
                Text(e.category ?? "Other")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if (e.items as? Set<ExpenseItem>)?.isEmpty == false {
                    Text("• Items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(formatAmount(e.amount, currency: e.currency))
                    .font(.subheadline)
            }

            if let d = e.expenseDate {
                Text(d, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for idx in offsets {
            viewContext.delete(expenses[idx])
        }
        try? viewContext.save()
    }

    private func createExpense() -> Expense {
        let e = Expense(context: viewContext)
        e.id = UUID()
        e.createdAt = Date()
        e.expenseDate = Date()
        e.currency = "KWD"
        e.category = "Vet"
        e.vendor = ""
        e.amount = 0
        e.pet = pet
        try? viewContext.save()
        return e
    }

    private func formatAmount(_ n: NSDecimalNumber?, currency: String?) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = (currency ?? "KWD").uppercased()
        return nf.string(from: n ?? 0) ?? "\(n?.stringValue ?? "0") \(currency ?? "")"
    }
}
