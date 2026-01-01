import SwiftUI
import CoreData

struct ExpenseDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var expense: Expense

    @State private var vendor: String = ""
    @State private var category: String = "Vet"
    @State private var currency: String = "KWD"
    @State private var amountText: String = ""
    @State private var date: Date = Date()

    var body: some View {
        Form {
            Section("Expense") {
                TextField("Vendor", text: $vendor)
                TextField("Category", text: $category)
                TextField("Currency", text: $currency)
                    .textInputAutocapitalization(.characters)
                TextField("Total Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }

            Section("Line Items") {
                if itemsArray.isEmpty {
                    Text("No line items.").foregroundStyle(.secondary)
                }

                ForEach(itemsArray) { item in
                    ExpenseItemRow(item: item)
                }
                .onDelete(perform: deleteItems)

                Button("Add Item") { addItem() }
            }

            if let doc = expense.sourceDocument {
                Section("Source Document") {
                    NavigationLink {
                        DocumentDetailView(document: doc)
                    } label: {
                        Text("Open scanned document")
                    }
                }
            }
        }
        .navigationTitle("Expense")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    save()
                    dismiss()
                }
            }
        }
        .onAppear { load() }
    }

    private var itemsArray: [ExpenseItem] {
        let set = expense.items as? Set<ExpenseItem> ?? []
        return set.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    private func load() {
        vendor = expense.vendor ?? ""
        category = expense.category ?? "Vet"
        currency = (expense.currency ?? "KWD").uppercased()
        amountText = (expense.amount ?? 0).stringValue
        date = expense.expenseDate ?? Date()
    }

    private func save() {
        expense.vendor = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.currency = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        expense.expenseDate = date

        if let d = parseDecimal(amountText) {
            expense.amount = NSDecimalNumber(decimal: d)
        }

        try? viewContext.save()
    }

    private func addItem() {
        let it = ExpenseItem(context: viewContext)
        it.id = UUID()
        it.createdAt = Date()
        it.title = ""
        it.amount = 0
        it.expense = expense
        try? viewContext.save()
    }

    private func deleteItems(at offsets: IndexSet) {
        let arr = itemsArray
        for idx in offsets {
            viewContext.delete(arr[idx])
        }
        try? viewContext.save()
    }

    private func parseDecimal(_ s: String) -> Decimal? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }

        let hasDot = t.contains(".")
        let hasComma = t.contains(",")

        var normalized = t

        if hasDot && hasComma {
            if let lastDot = t.lastIndex(of: "."), let lastComma = t.lastIndex(of: ",") {
                if lastDot > lastComma {
                    normalized = t.replacingOccurrences(of: ",", with: "")
                } else {
                    normalized = t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                }
            }
        } else if hasComma && !hasDot {
            normalized = t.replacingOccurrences(of: ",", with: ".")
        }

        return Decimal(string: normalized)
    }
}
