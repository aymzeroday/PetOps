import SwiftUI

struct ExtractionReviewResult {
    let chosenKind: DocKind
    let docTypeRaw: String
    let receipt: ReceiptDraft?
    let vaccine: VaccineDraft?
    let lab: LabDraft?
}

struct ReceiptItemDraft: Identifiable {
    var id: UUID = UUID()
    var title: String
    var amountText: String
}

struct ReceiptDraft {
    var vendor: String
    var currency: String
    var totalAmountText: String
    var date: Date
    var items: [ReceiptItemDraft]
}

struct VaccineDraft {
    var name: String
    var date: Date
}

struct LabDraft {
    var title: String
    var date: Date
}

struct ExtractionReviewView: View {
    let predicted: DocClassification
    let initialReceipt: ReceiptDraft?
    let initialVaccine: VaccineDraft?
    let initialLab: LabDraft?

    let onCancel: () -> Void
    let onSaveDocumentOnly: (ExtractionReviewResult) -> Void
    let onSaveAndCreate: (ExtractionReviewResult) -> Void

    @State private var chosenKind: DocKind
    @State private var receipt: ReceiptDraft
    @State private var vaccine: VaccineDraft
    @State private var lab: LabDraft

    init(
        predicted: DocClassification,
        initialReceipt: ReceiptDraft?,
        initialVaccine: VaccineDraft?,
        initialLab: LabDraft?,
        onCancel: @escaping () -> Void,
        onSaveDocumentOnly: @escaping (ExtractionReviewResult) -> Void,
        onSaveAndCreate: @escaping (ExtractionReviewResult) -> Void
    ) {
        self.predicted = predicted
        self.initialReceipt = initialReceipt
        self.initialVaccine = initialVaccine
        self.initialLab = initialLab
        self.onCancel = onCancel
        self.onSaveDocumentOnly = onSaveDocumentOnly
        self.onSaveAndCreate = onSaveAndCreate

        _chosenKind = State(initialValue: predicted.kind)

        _receipt = State(initialValue:
            initialReceipt ?? ReceiptDraft(
                vendor: "",
                currency: "KWD",
                totalAmountText: "",
                date: Date(),
                items: []
            )
        )

        _vaccine = State(initialValue:
            initialVaccine ?? VaccineDraft(name: "Vaccine", date: Date())
        )

        _lab = State(initialValue:
            initialLab ?? LabDraft(title: "Lab Results", date: Date())
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Prediction") {
                    HStack {
                        Text("Predicted")
                        Spacer()
                        Text(predicted.kind.rawValue.uppercased()).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Confidence")
                        Spacer()
                        Text(String(format: "%.0f%%", predicted.confidence * 100)).foregroundStyle(.secondary)
                    }
                    Text(predicted.reason).font(.caption).foregroundStyle(.secondary)
                }

                Section("Type") {
                    Picker("Document Type", selection: $chosenKind) {
                        ForEach(DocKind.allCases) { k in
                            Text(k.rawValue.capitalized).tag(k)
                        }
                    }
                }

                switch chosenKind {
                case .receipt:
                    receiptSection

                case .vaccine:
                    Section("Vaccine → Timeline Event") {
                        TextField("Vaccine Name", text: $vaccine.name)
                        DatePicker("Date", selection: $vaccine.date, displayedComponents: .date)
                    }

                case .lab:
                    Section("Lab → Timeline Event") {
                        TextField("Title", text: $lab.title)
                        DatePicker("Date", selection: $lab.date, displayedComponents: .date)
                    }

                case .other:
                    Section {
                        Text("Document will be saved only.").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Review Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save Only") {
                        onSaveDocumentOnly(buildResult())
                    }

                    Button("Save + Create") {
                        onSaveAndCreate(buildResult())
                    }
                    .disabled(!canCreate)
                }
            }
        }
    }

    private var receiptSection: some View {
        Group {
            Section("Receipt → Expense") {
                TextField("Vendor", text: $receipt.vendor)
                TextField("Currency", text: $receipt.currency)
                    .textInputAutocapitalization(.characters)

                TextField("Total Amount", text: $receipt.totalAmountText)
                    .keyboardType(.decimalPad)

                DatePicker("Date", selection: $receipt.date, displayedComponents: .date)
            }

            Section("Line Items (optional)") {
                if receipt.items.isEmpty {
                    Text("No items. Add items if the receipt contains multiple services.")
                        .foregroundStyle(.secondary)
                }

                ForEach(receipt.items.indices, id: \.self) { idx in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Item title", text: $receipt.items[idx].title)
                        TextField("Item amount", text: $receipt.items[idx].amountText)
                            .keyboardType(.decimalPad)
                    }
                    .padding(.vertical, 6)
                }
                .onDelete { offsets in
                    receipt.items.remove(atOffsets: offsets)
                }

                Button("Add Line Item") {
                    receipt.items.append(.init(title: "", amountText: ""))
                }
            }
        }
    }

    private var canCreate: Bool {
        switch chosenKind {
        case .receipt:
            return parseDecimal(receipt.totalAmountText) != nil
        case .vaccine:
            return !vaccine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .lab:
            return !lab.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .other:
            return false
        }
    }

    private func buildResult() -> ExtractionReviewResult {
        ExtractionReviewResult(
            chosenKind: chosenKind,
            docTypeRaw: chosenKind.rawValue,
            receipt: chosenKind == .receipt ? receipt : nil,
            vaccine: chosenKind == .vaccine ? vaccine : nil,
            lab: chosenKind == .lab ? lab : nil
        )
    }

    private func parseDecimal(_ s: String) -> Decimal? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        return Decimal(string: t)
    }
}
