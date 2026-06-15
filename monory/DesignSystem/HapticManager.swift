import UIKit

@MainActor
enum HapticManager {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)

    static func prepare() {
        light.prepare()
        rigid.prepare()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            light.impactOccurred()
            Task { @MainActor in light.prepare() }
        case .rigid:
            rigid.impactOccurred()
            Task { @MainActor in rigid.prepare() }
        default:
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
}
