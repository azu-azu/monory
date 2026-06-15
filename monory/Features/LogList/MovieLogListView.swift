import SwiftUI
import SwiftData

struct MovieLogListView: View {
    @Query(sort: \MovieLog.watchedAt, order: .reverse)
    private var logs: [MovieLog]

    @State private var showAddLog = false

    var body: some View {
        NavigationStack {
            Group {
                if logs.isEmpty {
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
            }
            .sheet(isPresented: $showAddLog) {
                AddMovieLogView()
            }
        }
    }

    private var list: some View {
        List {
            ForEach(logs) { log in
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
                if !log.theaterName.isEmpty {
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
