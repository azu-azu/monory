import SwiftUI
import SwiftData

struct MovieLogDetailView: View {
    let log: MovieLog

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTicket: TicketImage?
    @State private var showDeleteConfirmation = false
    @State private var showEdit = false

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
                if log.isStreaming && !log.viewingDates.isEmpty {
                    LabeledContent("初回視聴", value: log.watchedAtDisplay)
                    ForEach(log.viewingDates.sorted(by: { $0.date < $1.date })) { vd in
                        LabeledContent("視聴日", value: vd.date.formatted(date: .long, time: .omitted))
                    }
                } else {
                    LabeledContent("観た日", value: log.watchedAtDisplay)
                }
            }

            if let synopsis = log.movieSynopsis, !synopsis.isEmpty {
                Section("あらすじ") {
                    Text(synopsis)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            if log.isStreaming {
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

            Section("評価") {
                StarRatingView(rating: log.rating)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
            }
        }
        .sheet(isPresented: $showEdit) {
            EditMovieLogView(log: log)
        }
        .confirmationDialog("このログを削除しますか？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                context.delete(log)
                dismiss()
            }
        }
        .fullScreenCover(item: $selectedTicket) { ticket in
            if let uiImage = UIImage(data: ticket.imageData) {
                PhotoViewerSheet(image: uiImage)
            }
        }
    }
}
