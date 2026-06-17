import SwiftUI
import SwiftData

struct MovieLogListView: View {
    @Query(sort: \MovieLog.watchedAt, order: .reverse)
    private var logs: [MovieLog]

    @State private var showAddLog = false
    @State private var quickScanSource: QuickScanSource?

    private var pastLogs: [MovieLog] {
        logs.filter { !$0.isUpcoming }
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
            .navigationTitle("Monory")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddLog = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
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
                    } label: {
                        Image(systemName: "ticket")
                    }
                }
            }
            .sheet(isPresented: $showAddLog) {
                AddMovieLogView()
            }
            .sheet(item: $quickScanSource) { source in
                AddMovieLogView(quickScanSource: source)
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(pastLogs) { log in
                    NavigationLink(destination: MovieLogDetailView(log: log)) {
                        PosterCell(log: log)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
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

            Text(log.movieTitle.isEmpty ? "無題" : log.movieTitle)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .lineLimit(2)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
    }
}
