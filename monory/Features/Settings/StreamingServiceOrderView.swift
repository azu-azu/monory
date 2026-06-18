import SwiftUI

struct StreamingServiceOrderView: View {
    @Environment(StreamingServiceStore.self) private var store

    var body: some View {
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
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                }
                .onMove { indices, newOffset in
                    store.services.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .navigationTitle("配信サービスの並び替え")
        .navigationBarTitleDisplayMode(.inline)
    }
}
