import SwiftUI
import SwiftData
import PhotosUI

enum QuickScanSource {
    case camera
    case library
}

struct AddMovieLogView: View {
    let quickScanSource: QuickScanSource?

    private static let sheetAnimationDelay = Duration.milliseconds(600)

    init(quickScanSource: QuickScanSource? = nil) {
        self.quickScanSource = quickScanSource
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = AddMovieLogViewModel()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showTicketCamera = false
    @State private var showScanLibraryPicker = false
    @State private var scanLibraryItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("作品") {
                    TextField("映画タイトル", text: $viewModel.movieTitle)
                        .onChange(of: viewModel.movieTitle) { _, newValue in
                            viewModel.onTitleChanged(newValue)
                        }

                    if viewModel.isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        ForEach(viewModel.searchResults.prefix(5)) { movie in
                            Button {
                                Task { await viewModel.selectMovie(movie) }
                            } label: {
                                TMDBMovieRow(movie: movie)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let movie = viewModel.selectedTMDBMovie {
                        SelectedMovieCard(
                            movie: movie,
                            posterData: viewModel.selectedPosterData,
                            onClear: { viewModel.clearSelection() }
                        )
                    }

                    DatePicker("観た日", selection: $viewModel.watchedAt, displayedComponents: .date)
                }

                Section("映画館") {
                    TextField("映画館名", text: $viewModel.theaterName)
                    TextField("スクリーン番号", text: $viewModel.screenNumber)
                    TextField("座席番号", text: $viewModel.seatNumber)
                    Picker("上映形式", selection: $viewModel.screeningFormat) {
                        ForEach(ScreeningFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                }

                Section("感想") {
                    TextField("感想を書く...", text: $viewModel.review, axis: .vertical)
                        .lineLimit(5...10)
                        .keyboardCloseToolbar()
                }

                Section("チケット画像") {
                    PhotosPicker(selection: $selectedItems, matching: .images) {
                        Label("画像を追加", systemImage: "plus.circle")
                    }

                    if !viewModel.ticketDrafts.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.ticketDrafts.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        if let uiImage = UIImage(data: viewModel.ticketDrafts[index].imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipped()
                                                .cornerRadius(8)
                                        }
                                        Button {
                                            viewModel.ticketDrafts.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .black.opacity(0.6))
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("記録を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        viewModel.save(in: context)
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: selectedItems) { _, newItems in
                Task {
                    await viewModel.loadAndAddTicketImages(newItems)
                    selectedItems = []
                }
            }
            .onChange(of: scanLibraryItems) { _, newItems in
                Task {
                    await viewModel.loadAndAddTicketImages(newItems)
                    scanLibraryItems = []
                }
            }
            .task {
                guard let source = quickScanSource else { return }
                // sheet アニメーション完了を待つ
                try? await Task.sleep(for: Self.sheetAnimationDelay)
                switch source {
                case .camera:  showTicketCamera = true
                case .library: showScanLibraryPicker = true
                }
            }
            .fullScreenCover(isPresented: $showTicketCamera) {
                CameraPickerView { data in
                    Task { await viewModel.addTicketImage(data) }
                }
            }
            .photosPicker(
                isPresented: $showScanLibraryPicker,
                selection: $scanLibraryItems,
                matching: .images
            )
        }
    }
}

private struct TMDBMovieRow: View {
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

private struct SelectedMovieCard: View {
    let movie: TMDBMovie
    let posterData: Data?
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let data = posterData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 56)
                    .clipped()
                    .cornerRadius(4)
            } else {
                RoundedRectangle(cornerRadius: 4)
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
