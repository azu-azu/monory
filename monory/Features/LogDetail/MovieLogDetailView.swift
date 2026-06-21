import SwiftUI
import SwiftData

struct MovieLogDetailView: View {
    let log: MovieLog

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTicket: TicketImage?
    @State private var showDeleteConfirmation = false
    @State private var showEdit = false
    @State private var showMetadataSheet = false
    @State private var showSynopsisSheet = false

    var body: some View {
        let hasSynopsis = log.movieSynopsis?.isEmpty == false

        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.displayTitle)
                        .font(.headline)

                    if let originalTitle = log.movieOriginalTitle {
                        Text(originalTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let year = log.movieReleaseYear {
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if log.tmdbId != nil || hasSynopsis {
                Section {
                    if log.tmdbId != nil {
                        Button {
                            showMetadataSheet = true
                        } label: {
                            detailLinkLabel("作品詳細", systemImage: "film")
                        }
                        .buttonStyle(.plain)
                    }

                    if hasSynopsis {
                        Button {
                            showSynopsisSheet = true
                        } label: {
                            detailLinkLabel("あらすじ", systemImage: "text.alignleft")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("視聴記録") {
                if log.isMedia && !log.viewingDates.isEmpty {
                    LabeledContent("初回視聴", value: log.watchedAtDisplay)
                    ForEach(log.viewingDates.sorted(by: { $0.date < $1.date })) { vd in
                        LabeledContent("視聴日", value: vd.date.formatted(date: .long, time: .omitted))
                    }
                } else {
                    LabeledContent("観た日", value: log.watchedAtDisplay)
                }
                if log.isMedia {
                    LabeledContent("メディア", value: log.streamingService ?? "—")
                }
            }

            if !log.isMedia {
                Section("映画館") {
                    LabeledContent("映画館", value: log.theaterName.isEmpty ? "—" : log.theaterName)
                    LabeledContent("スクリーン", value: log.screenNumber ?? "—")
                    LabeledContent("座席", value: log.seatNumber ?? "—")
                    LabeledContent("上映形式", value: log.screeningFormat)
                    if let fee = log.admissionFee {
                        LabeledContent("料金", value: "¥\(fee)")
                    }
                    if !log.theaterMemo.isEmpty {
                        LabeledContent("メモ", value: log.theaterMemo)
                    }
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
                                        .cornerRadius(CornerRadius.standard)
                                        .onTapGesture {
                                            selectedTicket = ticket
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                log.updatedAt = Date()
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
        .navigationTitle(log.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showMetadataSheet) {
            MovieMetadataSheet(log: log)
        }
        .sheet(isPresented: $showSynopsisSheet) {
            MovieSynopsisSheet(synopsis: log.movieSynopsis ?? "")
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

    private func detailLinkLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.primary)
    }
}

private struct MovieSynopsisSheet: View {
    let synopsis: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(synopsis)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("あらすじ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
