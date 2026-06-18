import SwiftUI
import SwiftData

struct ExportView: View {
    @Query private var logs: [MovieLog]
    @State private var exportURL: URL?
    @State private var exportError: Bool = false

    var body: some View {
        List {
            Section {
                if let url = exportURL {
                    ShareLink(
                        item: url,
                        subject: Text("monory ログデータ"),
                        message: Text("映画ログをCSVでエクスポートします"),
                        preview: SharePreview(
                            MovieLogExporter.fileName(),
                            image: Image(systemName: "doc.text")
                        )
                    ) {
                        Label("CSVをエクスポート", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Label("CSVをエクスポート", systemImage: "square.and.arrow.up")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("\(logs.count)件のログをエクスポートします")
            }
        }
        .navigationTitle("CSVエクスポート")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            exportURL = buildExportURL()
        }
        .alert("エクスポートに失敗しました", isPresented: $exportError) {
            Button("OK", role: .cancel) {}
        }
    }

    private func buildExportURL() -> URL? {
        let data = MovieLogExporter.export(logs: logs)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(MovieLogExporter.fileName())
        do {
            try data.write(to: url)
            return url
        } catch {
            exportError = true
            return nil
        }
    }
}
