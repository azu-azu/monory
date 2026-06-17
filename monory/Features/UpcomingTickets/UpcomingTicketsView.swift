import SwiftUI
import SwiftData

struct UpcomingTicketsView: View {
    @Query(sort: \MovieLog.watchedAt, order: .forward)
    private var allLogs: [MovieLog]

    @State private var showAddLog = false
    @State private var quickScanSource: QuickScanSource?

    private var upcomingLogs: [MovieLog] {
        allLogs.filter(\.isUpcoming)
    }

    var body: some View {
        NavigationStack {
            Group {
                if upcomingLogs.isEmpty {
                    emptyState
                } else {
                    ticketList
                }
            }
            .navigationTitle("チケット")
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
                        Image(systemName: "qrcode.viewfinder")
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

    private var ticketList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(upcomingLogs) { log in
                    NavigationLink(destination: MovieLogDetailView(log: log)) {
                        UpcomingTicketCard(log: log)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "ticket")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("予定中のチケットなし")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("右上のアイコンからチケットをスキャンしよう")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

private struct UpcomingTicketCard: View {
    let log: MovieLog

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // メイン情報エリア
            HStack(alignment: .top, spacing: 12) {
                posterView

                VStack(alignment: .leading, spacing: 6) {
                    Text(log.movieTitle.isEmpty ? "無題" : log.movieTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if !log.theaterName.isEmpty {
                        Label(log.theaterName, systemImage: "mappin")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Text(log.watchedAt.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 8)

                daysUntilBadge
            }
            .padding()

            // ミシン目
            ticketPerforation

            // スタブ情報
            stubRow
                .padding(.horizontal)
                .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    @ViewBuilder
    private var posterView: some View {
        if let data = log.moviePosterData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 80)
                .clipped()
                .cornerRadius(6)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 56, height: 80)
                .overlay(
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                )
        }
    }

    private var daysUntilBadge: some View {
        let days = daysUntil
        let label = days == 1 ? "明日" : "\(days)日後"
        let color: Color = days == 1 ? .red : (days <= 3 ? .orange : Color.accentColor)
        return Text(label)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color)
            .clipShape(Capsule())
    }

    private var daysUntil: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: log.watchedAt)
        return Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
    }

    private var ticketPerforation: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .foregroundStyle(Color.secondary.opacity(0.25))
        }
        .frame(height: 1)
    }

    @ViewBuilder
    private var stubRow: some View {
        HStack(spacing: 16) {
            if let screen = log.screenNumber, !screen.isEmpty {
                Label(screen, systemImage: "rectangle.split.3x1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let seat = log.seatNumber, !seat.isEmpty {
                Label(seat, systemImage: "chair")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let format = ScreeningFormat(rawValue: log.screeningFormat), format != .standard {
                Text(log.screeningFormat)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }
}
