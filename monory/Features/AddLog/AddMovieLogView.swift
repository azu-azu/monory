import SwiftUI
import SwiftData
import PhotosUI

enum QuickScanSource: String, Identifiable {
    case camera
    case library
    var id: String { rawValue }
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

    @ViewBuilder
    private func viewingTypeButton(_ type: ViewingType, icon: String, label: String) -> some View {
        Button {
            viewModel.viewingType = type
        } label: {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .fontWeight(viewModel.viewingType == type ? .semibold : .regular)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    viewModel.viewingType == type
                        ? Color.accentColor
                        : Color.secondary.opacity(0.12)
                )
                .foregroundStyle(viewModel.viewingType == type ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showTicketCamera = false
    @State private var showScanLibraryPicker = false
    @State private var scanLibraryItems: [PhotosPickerItem] = []
    @State private var viewingDraftImage: UIImage?

    var body: some View {
        NavigationStack {
            Form {
                Section("作品") {
                    HStack {
                        TextField("映画タイトル", text: $viewModel.movieTitle)
                            .onChange(of: viewModel.movieTitle) { _, newValue in
                                viewModel.onTitleChanged(newValue)
                            }
                        if !viewModel.movieTitle.isEmpty {
                            Button {
                                viewModel.clearAll()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
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

                    if viewModel.viewingType == .theater {
                        DatePicker("観た日", selection: $viewModel.watchedAt, displayedComponents: .date)
                    }
                }

                Section {
                    HStack(spacing: 8) {
                        viewingTypeButton(.theater, icon: "film", label: "映画館")
                        viewingTypeButton(.streaming, icon: "tv", label: "配信")
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                if viewModel.viewingType == .theater {
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
                } else {
                    Section("配信") {
                        Picker("サービス", selection: $viewModel.streamingService) {
                            ForEach(AddMovieLogViewModel.streamingServices, id: \.self) { service in
                                Text(service).tag(service)
                            }
                        }
                        if viewModel.streamingService == AddMovieLogViewModel.otherServiceOption {
                            TextField("サービス名", text: $viewModel.customStreamingService)
                        }
                    }

                    Section("視聴日") {
                        DatePicker("初回", selection: $viewModel.watchedAt, displayedComponents: .date)
                        ForEach($viewModel.additionalDates) { $item in
                            HStack {
                                DatePicker("", selection: $item.date, displayedComponents: .date)
                                    .labelsHidden()
                                Spacer()
                                Button {
                                    viewModel.additionalDates.removeAll { $0.id == item.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Button {
                            viewModel.additionalDates.append(IdentifiableDate(date: Date()))
                        } label: {
                            Label("視聴日を追加", systemImage: "plus.circle")
                        }
                    }
                }

                Section("感想") {
                    TextField("感想を書く...", text: $viewModel.review, axis: .vertical)
                        .lineLimit(5...10)
                        .keyboardCloseToolbar()
                }

                if viewModel.viewingType == .theater {
                    Section("チケット画像") {
                        PhotosPicker(selection: $selectedItems, matching: .images) {
                            Label("画像を追加", systemImage: "plus.circle")
                        }

                        if !viewModel.ticketDrafts.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.ticketDrafts) { draft in
                                        ZStack(alignment: .topTrailing) {
                                            if let uiImage = UIImage(data: draft.imageData) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 80)
                                                    .clipped()
                                                    .cornerRadius(8)
                                                    .onTapGesture {
                                                        viewingDraftImage = uiImage
                                                    }
                                            }
                                            Button {
                                                viewModel.ticketDrafts.removeAll { $0.id == draft.id }
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
                guard !newItems.isEmpty else { return }
                Task {
                    await viewModel.loadAndAddTicketImages(newItems)
                    selectedItems = []
                }
            }
            .onChange(of: scanLibraryItems) { _, newItems in
                guard !newItems.isEmpty else { return }
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
            .fullScreenCover(isPresented: Binding(
                get: { viewingDraftImage != nil },
                set: { if !$0 { viewingDraftImage = nil } }
            )) {
                if let image = viewingDraftImage {
                    PhotoViewerSheet(image: image)
                }
            }
            .photosPicker(
                isPresented: $showScanLibraryPicker,
                selection: $scanLibraryItems,
                maxSelectionCount: 1,
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
