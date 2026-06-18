import SwiftUI

struct SettingsView: View {
    @Environment(StreamingServiceStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.services, id: \.self) { service in
                        Text(service)
                    }
                    .onMove { indices, newOffset in
                        store.services.move(fromOffsets: indices, toOffset: newOffset)
                    }
                } header: {
                    Text("配信サービス")
                } footer: {
                    Text("ドラッグして並び替えができる")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
