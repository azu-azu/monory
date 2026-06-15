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
