import SwiftUI
import CoreData

struct ExpenseEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let pet: Pet
    let expense: Expense?

    @State private var amountText: String = ""
    @State private var currency: String = "KWD"
    @State private var category: String = "Vet"
    @State private var vendor: String = ""
    @State private var date: Date = Date()

    private let categories = ["Vet", "Medication", "Food", "Litter", "Grooming", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)

                    TextField("Currency", text: $currency)
                        .textInputAutocapitalization(.characters)

                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Details") {
                    TextField("Vendor (optional)", text: $vendor)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle(expense == nil ? "Add Expense" : "Edit Expense")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.disabled(parsedAmount == nil)
                }
            }
            .onAppear { load() }
        }
    }

    private var parsedAmount: Decimal? {
        let s = amountText.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: s)
    }

    private func load() {
        guard let e = expense else { return }
        let amt = (e.amount as Decimal?) ?? 0
        amountText = NSDecimalNumber(decimal: amt).stringValue
        currency = e.currency ?? "KWD"
        category = e.category ?? "Vet"
        vendor = e.vendor ?? ""
        date = e.expenseDate ?? Date()
    }

    private func save() {
        guard let amt = parsedAmount else { return }

        let e = expense ?? Expense(context: viewContext)
        if e.id == nil { e.id = UUID() }
        if e.createdAt == nil { e.createdAt = Date() }

        e.amount = amt as NSDecimalNumber
        e.currency = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        e.category = category
        e.vendor = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
        e.expenseDate = date
        e.pet = pet

        try? viewContext.save()
        dismiss()
    }
}
