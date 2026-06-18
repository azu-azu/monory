import SwiftUI

struct SettingsView: View {
    @Environment(StreamingServiceStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.services, id: \.self) { service in
                        Text(service)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
