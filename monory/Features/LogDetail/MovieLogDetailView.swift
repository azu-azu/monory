import SwiftUI
import SwiftData

struct MovieLogDetailView: View {
    let log: MovieLog

    @Environment(\.modelContext) private var context
    @State private var selectedTicket: TicketImage?

    var body: some View {
        List {
            // Poster
            if let data = log.moviePosterData, let uiImage = UIImage(data: data) {
                Section {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(8)
                        .listRowInsets(EdgeInsets())
                }
            }

            Section {
                LabeledContent("映画タイトル", value: log.movieTitle.isEmpty ? "—" : log.movieTitle)
                if let originalTitle = log.movieOriginalTitle {
                    LabeledContent("原題", value: originalTitle)
                }
                if let year = log.movieReleaseYear {
                    LabeledContent("公開年", value: String(year))
                }
                LabeledContent("観た日", value: log.watchedAt.formatted(date: .long, time: .omitted))
            }

            if let synopsis = log.movieSynopsis, !synopsis.isEmpty {
                Section("あらすじ") {
                    Text(synopsis)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            if log.viewingType == ViewingType.streaming.rawValue {
                Section("配信") {
                    LabeledContent("サービス", value: log.streamingService ?? "—")
                }
            } else {
                Section("映画館") {
                    LabeledContent("映画館", value: log.theaterName.isEmpty ? "—" : log.theaterName)
                    LabeledContent("スクリーン", value: log.screenNumber ?? "—")
                    LabeledContent("座席", value: log.seatNumber ?? "—")
                    LabeledContent("上映形式", value: log.screeningFormat)
                }
            }

            if !log.review.isEmpty {
                Section("感想") {
                    Text(log.review)
                        .font(.body)
                }
            }

            if !log.ticketImages.isEmpty {
                Section("チケット画像") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(log.ticketImages) { ticket in
                                if let uiImage = UIImage(data: ticket.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipped()
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            selectedTicket = ticket
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                context.delete(ticket)
                                            } label: {
                                                Label("削除", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(log.movieTitle.isEmpty ? "無題" : log.movieTitle)
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(item: $selectedTicket) { ticket in
            TicketImageFullScreenView(ticket: ticket)
        }
    }
}

private struct TicketImageFullScreenView: View {
    let ticket: TicketImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let uiImage = UIImage(data: ticket.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .black.opacity(0.5))
                    .padding()
            }
        }
    }
}
