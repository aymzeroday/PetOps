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
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
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

            // No OCR on import (yet), so classify as other
            doc.type = "other"

            try viewContext.save()
        } catch {
            errorMessage = "\(error)"
        }
    }

    private func handleScan(images: [UIImage]) async {
        guard let pet = selectedPet else { return }
        do {
            guard let pdfData = PDFBuilder.makePDF(from: images) else { return }
            let savedPath = try FileStore.shared.save(data: pdfData, ext: "pdf")

            let ocr = try await OCRService.shared.recognizeText(from: images)

            await MainActor.run {
                // 1) Create Document
                let doc = Document(context: viewContext)
                doc.id = UUID()
                doc.filePath = savedPath
                doc.ocrText = ocr
                doc.createdAt = Date()
                doc.pet = pet

                // 2) Classify + tag
                let cls = DocClassifier.classify(ocr: ocr)
                doc.type = cls.kind.rawValue

                // 3) Auto-create structured record (baseline)
                switch cls.kind {
                case .receipt:
                    let r = DocExtractor.extractReceipt(ocr: ocr)
                    let e = Expense(context: viewContext)
                    e.id = UUID()
                    e.createdAt = Date()
                    e.expenseDate = r.date ?? Date()
                    e.currency = r.currency ?? "KWD"
                    e.category = "Vet"
                    e.vendor = r.vendor ?? ""
                    e.amount = NSDecimalNumber(decimal: r.total ?? 0)
                    e.pet = pet

                case .vaccine:
                    let v = DocExtractor.extractVaccine(ocr: ocr)
                    let ev = TimelineEvent(context: viewContext)
                    ev.id = UUID()
                    ev.createdAt = Date()
                    ev.type = "vaccine"
                    ev.title = v.vaccineName ?? "Vaccine"
                    ev.eventDate = v.date ?? Date()
                    ev.notes = "Auto-created from scanned document"
                    ev.pet = pet

                case .lab:
                    let ev = TimelineEvent(context: viewContext)
                    ev.id = UUID()
                    ev.createdAt = Date()
                    ev.type = "lab"
                    ev.title = "Lab Results"
                    ev.eventDate = Date()
                    ev.notes = "Auto-created from scanned document"
                    ev.pet = pet

                case .other:
                    break
                }

                // 4) Save once (document + any created objects)
                try? viewContext.save()
            }
        } catch {
            await MainActor.run { errorMessage = "\(error)" }
        }
    }
}
