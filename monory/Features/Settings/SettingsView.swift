import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("配信サービスの並び替え") {
                    StreamingServiceOrderView()
                }
                NavigationLink("CSVエクスポート") {
                    ExportView()
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
