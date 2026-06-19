import SwiftUI

// MARK: - dynamicFont

extension Font {
    static func dynamicFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .rounded
    ) -> Font {
        .system(size: size, weight: weight, design: design)
    }
}

// MARK: - CircleIconButton
// 丸アイコンボタン。haptic .light 内蔵。

struct CircleIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.impact(.light)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.dynamicFont(size: 17, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(CommonBackgroundColors.card, in: Circle())
        }
    }
}

// MARK: - cardStyle

private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(CommonBackgroundColors.card, in: RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - keyboardCloseToolbar
// キーボード閉じるボタン。.safeAreaInset ではなく .toolbar(placement: .keyboard) を使う。

extension View {
    func keyboardCloseToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    HapticManager.impact(.light)
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
            }
        }
    }
}

// MARK: - StarRatingView
// rating: Int? (nil=未評価, 1-5)。editing=true でタップ選択可。

struct StarRatingView: View {
    let rating: Int?
    var editing: Bool = false
    var onSelect: ((Int?) -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                    .foregroundStyle(star <= (rating ?? 0) ? Color.yellow : Color.secondary.opacity(0.4))
                    .font(.system(size: editing ? 28 : 16))
                    .onTapGesture {
                        guard editing else { return }
                        // 同じ星をタップしたらクリア（nil = 未評価）
                        onSelect?(star == rating ? nil : star)
                    }
            }
        }
        .animation(.easeInOut(duration: 0.1), value: rating)
    }
}

// MARK: - ViewingTypeToggle
// 映画館/配信 切り替えボタン行。AddMovieLogView・EditMovieLogView 共用。

struct ViewingTypeToggle: View {
    @Binding var selection: ViewingType

    var body: some View {
        HStack(spacing: 8) {
            toggleButton(.theater,   icon: "film", label: "映画館")
            toggleButton(.media, icon: "tv",   label: "メディア")
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    @ViewBuilder
    private func toggleButton(_ type: ViewingType, icon: String, label: String) -> some View {
        Button {
            selection = type
        } label: {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .fontWeight(selection == type ? .semibold : .regular)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    selection == type
                        ? Color.accentColor
                        : Color.secondary.opacity(0.12)
                )
                .foregroundStyle(selection == type ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - RaisedButtonStyle

struct RaisedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.accent)
                    .shadow(
                        color: .black.opacity(configuration.isPressed ? 0 : 0.2),
                        radius: configuration.isPressed ? 0 : 4,
                        y: configuration.isPressed ? 0 : 2
                    )
            )
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
