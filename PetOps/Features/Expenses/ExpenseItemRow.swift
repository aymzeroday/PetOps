import SwiftUI
import CoreData

struct ExpenseItemRow: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var item: ExpenseItem

    @State private var title: String = ""
    @State private var amountText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $title)
            TextField("Amount", text: $amountText)
                .keyboardType(.decimalPad)
        }
        .padding(.vertical, 6)
        .onAppear {
            title = item.title ?? ""
            amountText = (item.amount ?? 0).stringValue
        }
        .onChange(of: title) { _, _ in persist() }
        .onChange(of: amountText) { _, _ in persist() }
    }

    private func persist() {
        item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = parseDecimal(amountText) {
            item.amount = NSDecimalNumber(decimal: d)
        }
        try? viewContext.save()
    }

    private func parseDecimal(_ s: String) -> Decimal? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        return Decimal(string: t.replacingOccurrences(of: ",", with: "."))
    }
}
