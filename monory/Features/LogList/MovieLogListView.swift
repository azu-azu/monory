import SwiftUI
import SwiftData

enum LogSortOrder: String, CaseIterable {
    case dateDescending  = "日付（新しい順）"
    case dateAscending   = "日付（古い順）"
    case ratingDescending = "評価（高い順）"
    case titleAscending  = "タイトル（あいうえお順）"
}

enum LogFilter: String, CaseIterable {
    case all     = "全て"
    case theater = "映画館"
    case media   = "メディア"
}

struct MovieLogListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \MovieLog.watchedAt, order: .reverse)
    private var logs: [MovieLog]

    @State private var showAddLog = false
    @State private var quickScanSource: QuickScanSource?
    @State private var sortOrder: LogSortOrder = .dateDescending
    @State private var logFilter: LogFilter = .all

    private var pastLogs: [MovieLog] {
        let base = logs.filter { log in
            guard !log.isUpcoming else { return false }
            switch logFilter {
            case .all:     return true
            case .theater: return !log.isMedia
            case .media:   return log.isMedia
            }
        }
        return sorted(base)
    }

    var body: some View {
        NavigationStack {
            Group {
                if pastLogs.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                customHeader
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddLog) {
                AddMovieLogView()
            }
            .sheet(item: $quickScanSource) { source in
                AddMovieLogView(quickScanSource: source)
            }
        }
    }

    private var customHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
            Text("Monory")
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
            Menu {
                ForEach(LogSortOrder.allCases, id: \.self) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        if sortOrder == order {
                            Label(order.rawValue, systemImage: "checkmark")
                        } else {
                            Text(order.rawValue)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            Menu {
                Button {
                    quickScanSource = .camera
                } label: {
                    Label("カメラで撮影", systemImage: "camera")
                }
                Button {
                    quickScanSource = .library
                } label: {
                    Label("ライブラリから選択", systemImage: "photo.on.rectangle")
                }
                Button {
                    quickScanSource = .paste
                } label: {
                    Label("クリップボードから貼り付け", systemImage: "doc.on.clipboard")
                }
            } label: {
                Image(systemName: "ticket")
            }
            Button {
                showAddLog = true
            } label: {
                Image(systemName: "plus")
            }
        }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Picker("フィルタ", selection: $logFilter) {
                ForEach(LogFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                spacing: 6
            ) {
                ForEach(pastLogs) { log in
                    NavigationLink(destination: MovieLogDetailView(log: log)) {
                        PosterCell(log: log)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            context.delete(log)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("まだ記録がない")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("右上の + から映画鑑賞を記録しよう")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sorted(_ list: [MovieLog]) -> [MovieLog] {
        switch sortOrder {
        case .dateDescending:
            return list.sorted {
                if $0.watchedAtUnknown != $1.watchedAtUnknown { return $1.watchedAtUnknown }
                return $0.watchedAt > $1.watchedAt
            }
        case .dateAscending:
            return list.sorted {
                if $0.watchedAtUnknown != $1.watchedAtUnknown { return $1.watchedAtUnknown }
                return $0.watchedAt < $1.watchedAt
            }
        case .ratingDescending:
            return list.sorted {
                let r0 = $0.rating ?? 0
                let r1 = $1.rating ?? 0
                if r0 != r1 { return r0 > r1 }
                if $0.watchedAtUnknown != $1.watchedAtUnknown { return $1.watchedAtUnknown }
                return $0.watchedAt > $1.watchedAt
            }
        case .titleAscending:
            return list.sorted { $0.movieTitle.localizedCompare($1.movieTitle) == .orderedAscending }
        }
    }
}

private struct PosterCell: View {
    let log: MovieLog

    var body: some View {
        ZStack(alignment: .bottom) {
            posterBackground
            if log.moviePosterData != nil {
                titleOverlay
            }
        }
        .aspectRatio(2/3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var posterBackground: some View {
        if let data = log.moviePosterData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Color.secondary.opacity(0.12)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "film")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text(log.movieTitle.isEmpty ? "無題" : log.movieTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                )
        }
    }

    private var titleOverlay: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.75), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 72)

            Text(log.watchedAtDisplay)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
    }
}
