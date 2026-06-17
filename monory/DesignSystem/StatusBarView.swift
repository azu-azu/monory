import SwiftUI

private enum StatusBarLayout {
    static let horizontalPadding: CGFloat = 36
    static let topOffset: CGFloat = 18
    static let fallbackTop: CGFloat = 24
}

struct StatusBarView: View {
    let safeAreaTop: CGFloat

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        HStack {
            Text(Self.dateFormatter.string(from: now))
                .font(.dynamicFont(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(Self.timeFormatter.string(from: now))
                .font(.dynamicFont(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, StatusBarLayout.horizontalPadding)
        .padding(.top, safeAreaTop > 0 ? safeAreaTop + StatusBarLayout.topOffset : StatusBarLayout.fallbackTop)
        .onReceive(timer) { now = $0 }
    }
}
