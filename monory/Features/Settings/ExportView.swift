import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportView: View {
    @Environment(\.modelContext) private var context
    @Query private var logs: [MovieLog]

    @State private var exportURL: URL?
    @State private var exportError: Bool = false
    @State private var showImportPicker: Bool = false
    @State private var importResult: MovieLogImporter.ImportResult?
    @State private var importError: Bool = false

    var body: some View {
        List {
            // MARK: Export
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

            // MARK: Import
            Section {
                Button {
                    showImportPicker = true
                } label: {
                    Label("CSVからインポート", systemImage: "square.and.arrow.down")
                }
            } footer: {
                Text("エクスポートしたCSVから復元します。既存のログは削除されません。チケット画像・ポスター画像は含まれません。")
            }
        }
        .navigationTitle("バックアップ / 復元")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            exportURL = buildExportURL()
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("エクスポートに失敗しました", isPresented: $exportError) {
            Button("OK", role: .cancel) {}
        }
        .alert("インポート完了", isPresented: Binding(
            get: { importResult != nil },
            set: { if !$0 { importResult = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let r = importResult {
                Text(r.importSummary)
            }
        }
        .alert("インポートに失敗しました", isPresented: $importError) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Private

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

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let err) = result,
               (err as NSError).code == NSUserCancelledError { return }
            importError = true
            return
        }
        guard url.startAccessingSecurityScopedResource() else {
            importError = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else {
            importError = true
            return
        }
        importResult = MovieLogImporter.import(data: data, into: context)
    }
}
