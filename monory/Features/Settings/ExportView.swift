import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportView: View {
    @Environment(\.modelContext) private var context
    @Environment(StreamingServiceStore.self) private var serviceStore

    private var container: ModelContainer { context.container }
    @Query private var logs: [MovieLog]

    // CSV
    @State private var exportURL: URL?
    @State private var exportError: Bool = false
    @State private var showImportPicker: Bool = false
    @State private var importResult: MovieLogImporter.ImportResult?
    @State private var importError: Bool = false

    // Full Backup
    @State private var backupURL: URL?
    @State private var isExporting: Bool = false
    @State private var backupError: Bool = false
    @State private var showRestorePicker: Bool = false
    @State private var pendingRestoreURL: URL?
    @State private var showRestoreModeDialog: Bool = false
    @State private var showReplaceConfirm: Bool = false
    @State private var restoreResult: ImportResult?
    @State private var restoreError: String?

    var body: some View {
        List {
            // MARK: CSV Export
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

            // MARK: CSV Import
            Section {
                Button {
                    showImportPicker = true
                } label: {
                    Label("CSVからインポート", systemImage: "square.and.arrow.down")
                }
            } footer: {
                Text("エクスポートしたCSVから復元します。既存のログは削除されません。チケット画像・ポスター画像は含まれません。")
            }

            // MARK: Full Backup Export
            Section {
                Button {
                    backupURL = nil
                    Task { await buildBackup() }
                } label: {
                    if isExporting {
                        HStack {
                            ProgressView().padding(.trailing, 4)
                            Text("バックアップを作成中…")
                        }
                    } else {
                        Label("フルバックアップを作成", systemImage: "archivebox")
                    }
                }
                .disabled(isExporting)

                if let url = backupURL {
                    ShareLink(
                        item: url,
                        subject: Text("monory フルバックアップ"),
                        message: Text("映画ログのフルバックアップです"),
                        preview: SharePreview(
                            url.lastPathComponent,
                            image: Image(systemName: "archivebox")
                        )
                    ) {
                        Label("作成済みバックアップを共有", systemImage: "square.and.arrow.up")
                    }
                }
            } footer: {
                Text("画像・あらすじ・全フィールドを含む完全なバックアップを作成します。")
            }

            // MARK: Full Backup Restore
            Section {
                Button {
                    showRestorePicker = true
                } label: {
                    Label("フルバックアップから復元", systemImage: "arrow.counterclockwise")
                }
                .disabled(isExporting)
            } footer: {
                Text("バックアップから復元します。「置換」は現在のログを全て削除して復元します。「追加」は既存ログを残したまま統合します。")
            }
        }
        .navigationTitle("バックアップ / 復元")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            exportURL = buildExportURL()
        }
        // CSV import picker
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleCSVImport(result)
        }
        // Full backup restore picker
        .fileImporter(
            isPresented: $showRestorePicker,
            allowedContentTypes: [UTType("public.zip-archive") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleRestoreFilePicked(result)
        }
        .confirmationDialog(
            "復元方法を選択",
            isPresented: $showRestoreModeDialog,
            titleVisibility: .visible
        ) {
            Button("置換（現在のデータを全て削除）", role: .destructive) {
                showReplaceConfirm = true
            }
            Button("追加（既存データを残して統合）") {
                Task { await performRestore(mode: .merge) }
            }
        } message: {
            Text("「置換」を選ぶと現在の全ログと配信サービスの並びが削除・上書きされます。")
        }
        .alert("置換して復元しますか？", isPresented: $showReplaceConfirm) {
            Button("置換して復元", role: .destructive) {
                Task { await performRestore(mode: .replace) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("現在の全ログ・配信サービスの並びを削除し、バックアップの内容に完全置換します。この操作は取り消せません。")
        }
        // CSV alerts
        .alert("エクスポートに失敗しました", isPresented: $exportError) {
            Button("OK", role: .cancel) {}
        }
        .alert("インポート完了", isPresented: Binding(
            get: { importResult != nil },
            set: { if !$0 { importResult = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let r = importResult { Text(r.importSummary) }
        }
        .alert("インポートに失敗しました", isPresented: $importError) {
            Button("OK", role: .cancel) {}
        }
        // Full backup alerts
        .alert("バックアップの作成に失敗しました", isPresented: $backupError) {
            Button("OK", role: .cancel) {}
        }
        .alert("復元完了", isPresented: Binding(
            get: { restoreResult != nil },
            set: { if !$0 { restoreResult = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let r = restoreResult { Text(r.summary) }
        }
        .alert("復元に失敗しました", isPresented: Binding(
            get: { restoreError != nil },
            set: { if !$0 { restoreError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let msg = restoreError { Text(msg) }
        }
    }

    // MARK: - CSV

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

    private func handleCSVImport(_ result: Result<[URL], Error>) {
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

    // MARK: - Full Backup

    @MainActor
    private func buildBackup() async {
        isExporting = true
        backupURL = nil
        defer { isExporting = false }

        let snapshot = FullBackupExporter.makeSnapshot(logs: logs)
        do {
            backupURL = try await FullBackupExporter.export(snapshot: snapshot)
        } catch {
            backupError = true
        }
    }

    private func handleRestoreFilePicked(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let err) = result,
               (err as NSError).code == NSUserCancelledError { return }
            restoreError = "ファイルを開けませんでした"
            return
        }
        pendingRestoreURL = url
        showRestoreModeDialog = true
    }

    @MainActor
    private func performRestore(mode: ImportMode) async {
        guard let url = pendingRestoreURL else { return }
        guard url.startAccessingSecurityScopedResource() else {
            restoreError = "ファイルへのアクセスが許可されませんでした"
            return
        }
        defer {
            url.stopAccessingSecurityScopedResource()
            pendingRestoreURL = nil
        }

        do {
            restoreResult = try await FullBackupImporter.restore(
                from: url,
                in: container,
                mode: mode,
                serviceStore: serviceStore
            )
        } catch let error as BackupError {
            restoreError = error.localizedDescription
        } catch {
            restoreError = "復元中にエラーが発生しました"
        }
    }
}
