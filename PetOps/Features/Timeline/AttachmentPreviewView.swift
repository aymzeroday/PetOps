import SwiftUI

struct AttachmentPreviewView: View {
    let path: String

    var body: some View {
        NavigationStack {
            Group {
                if let data = FileManager.default.contents(atPath: path),
                   let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    ContentUnavailableView("Cannot preview", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationTitle(URL(fileURLWithPath: path).lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
