import SwiftUI

struct StreamingServiceOrderView: View {
    @Environment(StreamingServiceStore.self) private var store

    var body: some View {
        List {
            ForEach(store.services, id: \.self) { service in
                Text(service)
            }
            .onMove { indices, newOffset in
                store.services.move(fromOffsets: indices, toOffset: newOffset)
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(.active))
        .navigationTitle("配信サービスの並び替え")
        .navigationBarTitleDisplayMode(.inline)
    }
}
