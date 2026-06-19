import SwiftUI

struct StreamingServiceOrderView: View {
    @Environment(StreamingServiceStore.self) private var store

    var body: some View {
        List {
            ForEach(store.services, id: \.self) { service in
                Text(service)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
            }
            .onMove { indices, newOffset in
                store.services.move(fromOffsets: indices, toOffset: newOffset)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .navigationTitle("メディアサービスの並び替え")
        .navigationBarTitleDisplayMode(.inline)
    }
}
