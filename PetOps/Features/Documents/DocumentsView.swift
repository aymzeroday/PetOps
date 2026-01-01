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
                    .id(searchText) // force predicate refresh
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
            doc.type = "other"
            doc.filePath = savedPath
            doc.createdAt = Date()
            doc.pet = pet

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
                let doc = Document(context: viewContext)
                doc.id = UUID()
                doc.type = "other"
                doc.filePath = savedPath
                doc.ocrText = ocr
                doc.createdAt = Date()
                doc.pet = pet
                try? viewContext.save()
            }
        } catch {
            await MainActor.run { errorMessage = "\(error)" }
        }
    }
}
