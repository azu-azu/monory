import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("メディアサービスの並び替え") {
                    StreamingServiceOrderView()
                }
                NavigationLink("バックアップ / 復元") {
                    ExportView()
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
