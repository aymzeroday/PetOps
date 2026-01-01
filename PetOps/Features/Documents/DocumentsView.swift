import SwiftUI
import CoreData
import UniformTypeIdentifiers
import UIKit
import VisionKit
import AVFoundation

struct DocumentsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Pet.createdAt, ascending: true)])
    private var pets: FetchedResults<Pet>

    @State private var showingImporter = false
    @State private var showingScanner = false
    @State private var errorMessage: String?
    @State private var searchText: String = ""

    // Atomic review state
    @State private var pendingReview: PendingReview?

    private var selectedPet: Pet? {
        guard let id = appState.selectedPetID else { return nil }
        return pets.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            if pets.isEmpty {
                ContentUnavailableView("No pets", systemImage: "pawprint", description: Text("Create a pet first."))
                    .navigationTitle("Documents")
            } else if selectedPet == nil {
                ContentUnavailableView("No active pet", systemImage: "checkmark.circle", description: Text("Select a pet in Pets."))
                    .navigationTitle("Documents")
            } else {
                DocumentsList(pet: selectedPet!, query: searchText)
                    .id(searchText)
                    .navigationTitle("Documents")
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button { startScan() } label: { Image(systemName: "camera.viewfinder") }
                            Button { showingImporter = true } label: { Image(systemName: "plus") }
                        }
                    }
                    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .sheet(isPresented: $showingScanner) {
            DocumentScannerView(
                onComplete: { images in
                    showingScanner = false
                    Task { await handleScan(images: images) }
                },
                onCancel: { showingScanner = false },
                onError: { err in
                    showingScanner = false
                    errorMessage = "\(err)"
                }
            )
        }
        .sheet(item: $pendingReview) { review in
            ExtractionReviewView(
                predicted: review.classification,
                initialReceipt: review.receiptDraft,
                initialVaccine: review.vaccineDraft,
                initialLab: review.labDraft,
                onCancel: { cancelReview(review) },
                onSaveDocumentOnly: { res in saveDocumentOnly(res, review: review) },
                onSaveAndCreate: { res in saveAndCreate(res, review: review) }
            )
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func startScan() {
        guard VNDocumentCameraViewController.isSupported else {
            errorMessage = "Document scanning requires a physical iPhone/iPad camera. Use Import on Simulator."
            return
        }

        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    showingScanner = true
                } else {
                    errorMessage = "Camera permission denied. Enable it in iOS Settings."
                }
            }
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        guard let pet = selectedPet else { return }

        do {
            let url = try result.get().first!
            let gotAccess = url.startAccessingSecurityScopedResource()
            defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.isEmpty ? "bin" : url.pathExtension
            let savedPath = try FileStore.shared.save(data: data, ext: ext)

            let doc = Document(context: viewContext)
            doc.id = UUID()
            doc.filePath = savedPath
            doc.createdAt = Date()
            doc.pet = pet
            doc.type = "other"

            try viewContext.save()
        } catch {
            errorMessage = "\(error)"
        }
    }

    private func handleScan(images: [UIImage]) async {
        guard selectedPet != nil else { return }

        do {
            guard let pdfData = PDFBuilder.makePDF(from: images) else { return }
            let savedPath = try FileStore.shared.save(data: pdfData, ext: "pdf")

            let ocr = try await OCRService.shared.recognizeText(from: images)
            let cls = DocClassifier.classify(ocr: ocr)

            var receiptDraft: ReceiptDraft?
            var vaccineDraft: VaccineDraft?
            var labDraft: LabDraft?

            switch cls.kind {
            case .receipt:
                let r = DocExtractor.extractReceipt(ocr: ocr)
                receiptDraft = ReceiptDraft(
                    vendor: r.vendor ?? "",
                    currency: r.currency ?? "KWD",
                    totalAmountText: r.total.map { NSDecimalNumber(decimal: $0).stringValue } ?? "",
                    date: r.date ?? Date(),
                    items: parseReceiptItemDrafts(from: ocr)
                )

            case .vaccine:
                let v = DocExtractor.extractVaccine(ocr: ocr)
                vaccineDraft = VaccineDraft(
                    name: v.vaccineName ?? "Vaccine",
                    date: v.date ?? Date()
                )

            case .lab:
                labDraft = LabDraft(title: "Lab Results", date: Date())

            case .other:
                break
            }

            await MainActor.run {
                pendingReview = PendingReview(
                    filePath: savedPath,
                    ocr: ocr,
                    classification: cls,
                    receiptDraft: receiptDraft,
                    vaccineDraft: vaccineDraft,
                    labDraft: labDraft
                )
            }
        } catch {
            await MainActor.run { errorMessage = "\(error)" }
        }
    }

    // MARK: - Review actions

    private func cancelReview(_ review: PendingReview) {
        FileStore.shared.delete(path: review.filePath)
        pendingReview = nil
    }

    private func saveDocumentOnly(_ res: ExtractionReviewResult, review: PendingReview) {
        guard let pet = selectedPet else {
            FileStore.shared.delete(path: review.filePath)
            pendingReview = nil
            return
        }

        let doc = Document(context: viewContext)
        doc.id = UUID()
        doc.filePath = review.filePath
        doc.ocrText = review.ocr
        doc.createdAt = Date()
        doc.pet = pet
        doc.type = res.docTypeRaw

        try? viewContext.save()
        pendingReview = nil
    }

    private func saveAndCreate(_ res: ExtractionReviewResult, review: PendingReview) {
        guard let pet = selectedPet else {
            FileStore.shared.delete(path: review.filePath)
            pendingReview = nil
            return
        }

        // Always save the Document
        let doc = Document(context: viewContext)
        doc.id = UUID()
        doc.filePath = review.filePath
        doc.ocrText = review.ocr
        doc.createdAt = Date()
        doc.pet = pet
        doc.type = res.docTypeRaw

        switch res.chosenKind {
        case .receipt:
            guard let r = res.receipt else { break }
            guard let total = parseDecimal(r.totalAmountText) else { break }

            let e = Expense(context: viewContext)
            e.id = UUID()
            e.createdAt = Date()
            e.expenseDate = r.date
            e.currency = r.currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            e.category = "Vet"
            e.vendor = r.vendor.trimmingCharacters(in: .whitespacesAndNewlines)
            e.amount = NSDecimalNumber(decimal: total) // keep using your existing field name
            e.pet = pet

            // Optional line items
            for item in r.items {
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { continue }
                guard let itemAmt = parseDecimal(item.amountText) else { continue }

                let it = ExpenseItem(context: viewContext)
                it.id = UUID()
                it.createdAt = Date()
                it.title = title
                it.amount = NSDecimalNumber(decimal: itemAmt)
                it.expense = e
            }

        case .vaccine:
            guard let v = res.vaccine else { break }
            let ev = TimelineEvent(context: viewContext)
            ev.id = UUID()
            ev.createdAt = Date()
            ev.type = "vaccine"
            ev.title = v.name.trimmingCharacters(in: .whitespacesAndNewlines)
            ev.eventDate = v.date
            ev.notes = "Created from scanned document"
            ev.pet = pet

        case .lab:
            guard let l = res.lab else { break }
            let ev = TimelineEvent(context: viewContext)
            ev.id = UUID()
            ev.createdAt = Date()
            ev.type = "lab"
            ev.title = l.title.trimmingCharacters(in: .whitespacesAndNewlines)
            ev.eventDate = l.date
            ev.notes = "Created from scanned document"
            ev.pet = pet

        case .other:
            break
        }

        try? viewContext.save()
        pendingReview = nil
    }

    // MARK: - Helpers

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

    // Weak heuristic: grab a few "text + amount" lines
    private func parseReceiptItemDrafts(from ocr: String) -> [ReceiptItemDraft] {
        let lines = ocr
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var out: [ReceiptItemDraft] = []

        for line in lines {
            let lower = line.lowercased()
            if lower.contains("total") || lower.contains("subtotal") || lower.contains("vat") || lower.contains("tax") { continue }

            guard let token = firstDecimalToken(in: line) else { continue }

            let title = line
                .replacingOccurrences(of: token, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if title.count < 3 { continue }

            out.append(ReceiptItemDraft(title: title, amountText: token))

            if out.count >= 8 { break }
        }

        return out
    }

    private func firstDecimalToken(in text: String) -> String? {
        let pattern = #"(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|\d+(?:[.,]\d{2}))"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let ns = text as NSString
        let matches = regex?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? []
        guard let m = matches.first else { return nil }
        return ns.substring(with: m.range)
    }
}

private struct PendingReview: Identifiable {
    let id = UUID()
    let filePath: String
    let ocr: String
    let classification: DocClassification
    let receiptDraft: ReceiptDraft?
    let vaccineDraft: VaccineDraft?
    let labDraft: LabDraft?
}
