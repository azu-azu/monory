import SwiftUI
import SwiftData

struct ExportView: View {
    @Query private var logs: [MovieLog]

    var body: some View {
        List {
            Section {
                ShareLink(
                    item: exportItem(),
                    subject: Text("monory ログデータ"),
                    message: Text("映画ログをCSVでエクスポートします"),
                    preview: SharePreview(
                        MovieLogExporter.fileName(),
                        image: Image(systemName: "doc.text")
                    )
                ) {
                    Label("CSVをエクスポート", systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text("\(logs.count)件のログをエクスポートします")
            }
        }
        .navigationTitle("CSVエクスポート")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exportItem() -> URL {
        let data = MovieLogExporter.export(logs: logs)
        let fileName = MovieLogExporter.fileName()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)
        return url
    }
}
