import SwiftUI
import SwiftData
import PhotosUI

enum QuickScanSource: String, Identifiable {
    case camera
    case library
    case paste
    var id: String { rawValue }
}

struct AddMovieLogView: View {
    let quickScanSource: QuickScanSource?

    private static let sheetAnimationDelay = Duration.milliseconds(600)
    private static let currentYear = Calendar.current.component(.year, from: Date())

    init(quickScanSource: QuickScanSource? = nil, initialViewingType: ViewingType = .theater) {
        self.quickScanSource = quickScanSource
        _viewModel = State(initialValue: AddMovieLogViewModel(initialViewingType: initialViewingType))
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(StreamingServiceStore.self) private var streamingStore

    @State private var viewModel: AddMovieLogViewModel

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showTicketCamera = false
    @State private var showScanLibraryPicker = false
    @State private var scanLibraryItems: [PhotosPickerItem] = []
    @State private var viewingDraftImage: UIImage?
    @State private var showNoPasteImageAlert = false

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
                                viewModel.clearTitle()
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
                        TMDBSelectedMovieCard(
                            movie: movie,
                            posterData: viewModel.selectedPosterData,
                            onClear: { viewModel.clearSelection() }
                        )
                    }

                    if viewModel.viewingType == .theater {
                        dateSection
                    }
                }

                Section {
                    ViewingTypeToggle(selection: $viewModel.viewingType)
                }

                if viewModel.viewingType == .theater {
                    Section("映画館") {
                        HStack {
                            TextField("映画館名", text: $viewModel.theaterName)
                            if viewModel.hasTheaterInfo {
                                Button {
                                    viewModel.clearTheater()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        TextField("スクリーン番号", text: $viewModel.screenNumber)
                        TextField("座席番号", text: $viewModel.seatNumber)
                        LabeledContent("料金") {
                            TextField("0", text: $viewModel.admissionFeeText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        Picker("上映形式", selection: $viewModel.screeningFormat) {
                            ForEach(ScreeningFormat.allCases, id: \.self) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        TextField("メモ", text: $viewModel.theaterMemo)
                    }
                } else {
                    Section("メディア") {
                        Picker("サービス", selection: $viewModel.streamingService) {
                            ForEach(streamingStore.services, id: \.self) { service in
                                Text(service).tag(service)
                            }
                            Text(StreamingServiceStore.otherOption)
                                .tag(StreamingServiceStore.otherOption)
                        }
                        if viewModel.streamingService == StreamingServiceStore.otherOption {
                            TextField("サービス名", text: $viewModel.customStreamingService)
                        }
                    }

                    Section("視聴日") {
                        dateSection
                        if viewModel.watchedDateMode == .full {
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
                }

                Section("評価") {
                    HStack {
                        StarRatingView(rating: viewModel.rating, editing: true) { selected in
                            viewModel.rating = selected
                        }
                        Spacer()
                        if viewModel.rating != nil {
                            Button("クリア") { viewModel.rating = nil }
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                        Button {
                            pasteFromClipboard()
                        } label: {
                            Label("クリップボードから貼り付け", systemImage: "doc.on.clipboard")
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
                                                    .cornerRadius(CornerRadius.standard)
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
                // paste はシートアニメーション完了を待たない
                if source != .paste {
                    try? await Task.sleep(for: Self.sheetAnimationDelay)
                }
                switch source {
                case .camera:  showTicketCamera = true
                case .library: showScanLibraryPicker = true
                case .paste:   pasteFromClipboard()
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
            .alert("クリップボードに画像がありません", isPresented: $showNoPasteImageAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    // MARK: - Date section

    @ViewBuilder
    private var dateSection: some View {
        Picker("日付精度", selection: $viewModel.watchedDateMode) {
            ForEach(WatchedDateMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .disabled(viewModel.scannedFromTicket)

        switch viewModel.watchedDateMode {
        case .full:
            DatePicker(
                viewModel.viewingType == .theater ? "観た日" : "初回",
                selection: $viewModel.watchedAt,
                displayedComponents: .date
            )
        case .yearOnly:
            Stepper("\(viewModel.watchedYear)年", value: $viewModel.watchedYear, in: 1900...Self.currentYear)
        case .unknown:
            EmptyView()
        }
    }

    // MARK: - Clipboard

    private static let pasteJPEGQuality: CGFloat = 0.8

    private func pasteFromClipboard() {
        guard let image = UIPasteboard.general.image,
              let data = image.jpegData(compressionQuality: Self.pasteJPEGQuality) else {
            if quickScanSource == .paste {
                dismiss()
            } else {
                showNoPasteImageAlert = true
            }
            return
        }
        Task { await viewModel.addTicketImage(data) }
    }
}

