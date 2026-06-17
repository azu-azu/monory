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
                    list
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

    private var list: some View {
        List {
            ForEach(pastLogs) { log in
                NavigationLink(destination: MovieLogDetailView(log: log)) {
                    MovieLogRow(log: log)
                }
            }
        }
        .listStyle(.plain)
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

private struct MovieLogRow: View {
    let log: MovieLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(log.movieTitle.isEmpty ? "無題" : log.movieTitle)
                .font(.headline)
            HStack(spacing: 8) {
                Text(log.watchedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if log.isStreaming {
                    if let service = log.streamingService, !service.isEmpty {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(service)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if !log.theaterName.isEmpty {
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(log.theaterName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if !log.review.isEmpty {
                Text(log.review)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
