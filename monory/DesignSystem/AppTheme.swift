import SwiftUI

enum AppTheme {
    static let accent = Color.accentColor
    static let background = Color(.systemBackground)
}

enum CommonTextColors {
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.7)
}

enum CardTextColors {
    static let primary = Color(.label)
    static let secondary = Color(.secondaryLabel)
}

enum CommonBackgroundColors {
    static let card = Color(.secondarySystemBackground)
    static let overlay = Color.black.opacity(0.4)
}

enum InputColors {
    static let background = Color(.tertiarySystemBackground)
    static let placeholder = Color(.placeholderText)
}

enum StatusColors {
    static let danger = Color.red
    static let success = Color.green
    static let warning = Color.orange
}

enum CornerRadius {
    static let posterThumb: CGFloat = 4    // TMDB ポスターサムネイル (40×56)
    static let posterMedium: CGFloat = 4   // 中サイズポスター (56×80)
    static let standard: CGFloat = 6       // 画像・ボタン
    static let card: CGFloat = 8           // カード背景
    static let cardLarge: CGFloat = 10     // 大型カードコンテナ
}
