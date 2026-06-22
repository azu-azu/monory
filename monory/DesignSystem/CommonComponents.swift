import SwiftUI
import ImageIO
import UIKit

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
            .background(CommonBackgroundColors.card, in: RoundedRectangle(cornerRadius: CornerRadius.card))
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
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - TMDBMovieRow
// TMDB 検索候補の1行。AddMovieLogView・EditMovieLogView 共用。

struct TMDBMovieRow: View {
    let movie: TMDBMovie

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(movie.title)
                .font(.body)
                .foregroundStyle(.primary)
            if let year = movie.releaseYear {
                Text(String(year))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - TMDBSelectedMovieCard
// TMDB で選択済み映画カード（ポスター＋タイトル＋×ボタン）。Add/Edit 共用。

struct ThumbnailImageView: View {
    let imageData: Data
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.secondary.opacity(0.2))

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .cornerRadius(cornerRadius)
        .task(id: imageData) {
            guard thumbnail == nil else { return }
            await Task.yield()
            thumbnail = Self.makeThumbnail(
                from: imageData,
                maxPixelSize: max(width, height) * UIScreen.main.scale
            )
        }
    }

    private static func makeThumbnail(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: image)
    }
}

struct TMDBSelectedMovieCard: View {
    let movie: TMDBMovie
    let posterData: Data?
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let data = posterData {
                ThumbnailImageView(
                    imageData: data,
                    width: 40,
                    height: 56,
                    cornerRadius: CornerRadius.posterThumb
                )
            } else {
                RoundedRectangle(cornerRadius: CornerRadius.posterThumb)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 40, height: 56)
                    .overlay(Image(systemName: "film").foregroundStyle(.secondary))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if let year = movie.releaseYear {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !movie.originalTitle.isEmpty, movie.originalTitle != movie.title {
                    Text(movie.originalTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - RaisedButtonStyle

struct RaisedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)  // ボタン固有の丸み
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
