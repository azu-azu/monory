import SwiftUI
import SwiftData
import PhotosUI

struct EditMovieLogView: View {
    let log: MovieLog

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(StreamingServiceStore.self) private var streamingStore

    @State private var movieTitle: String
    @State private var watchedAt: Date
    @State private var watchedDateMode: WatchedDateMode
    @State private var watchedYear: Int
    @State private var viewingType: ViewingType
    @State private var theaterName: String
    @State private var theaterMemo: String
    @State private var screenNumber: String
    @State private var seatNumber: String
    @State private var screeningFormat: ScreeningFormat
    @State private var streamingService: String
    @State private var customStreamingService: String
    @State private var rating: Int?
    @State private var review: String
    @State private var additionalDates: [IdentifiableDate]
    @State private var admissionFeeText: String

    // TMDB search
    @State private var searchResults: [TMDBMovie] = []
    @State private var isSearching: Bool = false
    @State private var selectedTMDBMovie: TMDBMovie?
    @State private var selectedPosterData: Data?
    @State private var searchTask: Task<Void, Never>?
    @State private var posterTask: Task<Void, Never>?
    @State private var detailTask: Task<Void, Never>?
    @State private var draftMetadata: MovieMetadata?
    @State private var draftEnglishOverview: String?
    @State private var tmdbYearApplied: Bool

    @State private var selectedTicketItems: [PhotosPickerItem] = []
    @State private var showNoPasteImageAlert = false

    @State private var ocrResult: CinemaTicketResult?
    @State private var showOCRSheet = false
    @State private var showRescanEmptyAlert = false
    @State private var isScanning = false

    private static let currentYear = Calendar.current.component(.year, from: Date())
    private static let pasteJPEGQuality: CGFloat = 0.8

    init(log: MovieLog) {
        self.log = log
        _movieTitle     = State(initialValue: log.movieTitle)
        _watchedAt      = State(initialValue: log.watchedAt)
        _viewingType    = State(initialValue: ViewingType(rawValue: log.viewingType) ?? .theater)
        _theaterName    = State(initialValue: log.theaterName)
        _theaterMemo    = State(initialValue: log.theaterMemo)
        _screenNumber   = State(initialValue: log.screenNumber ?? "")
        _seatNumber     = State(initialValue: log.seatNumber ?? "")
        _screeningFormat = State(initialValue: ScreeningFormat(rawValue: log.screeningFormat) ?? .standard)
        _rating             = State(initialValue: log.rating)
        _review             = State(initialValue: log.review)
        _additionalDates = State(initialValue:
            log.viewingDates
                .sorted(by: { $0.date < $1.date })
                .map { IdentifiableDate(id: $0.id, date: $0.date) }
        )
        _admissionFeeText = State(initialValue: log.admissionFee.map { String($0) } ?? "")

        // watched date mode
        if log.watchedAtUnknown {
            _watchedDateMode = State(initialValue: .unknown)
            _watchedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
        } else if log.watchedYearOnly {
            _watchedDateMode = State(initialValue: .yearOnly)
            _watchedYear = State(initialValue: Calendar.current.component(.year, from: log.watchedAt))
        } else {
            _watchedDateMode = State(initialValue: .full)
            _watchedYear = State(initialValue: Calendar.current.component(.year, from: log.watchedAt))
        }

        // streaming service: preset か custom かを判定
        let knownServices = StreamingServiceStore.loadServices()
        let stored = log.streamingService ?? (knownServices.first ?? "Netflix")
        if knownServices.contains(stored) {
            _streamingService       = State(initialValue: stored)
            _customStreamingService = State(initialValue: "")
        } else {
            _streamingService       = State(initialValue: StreamingServiceStore.otherOption)
            _customStreamingService = State(initialValue: stored)
        }

        // TMDB: 既存データから復元
        if let tmdbId = log.tmdbId {
            let movie = TMDBMovie(
                id: tmdbId,
                title: log.movieTitle,
                originalTitle: log.movieOriginalTitle ?? log.movieTitle,
                overview: log.movieSynopsis ?? "",
                releaseDate: log.movieReleaseYear.map { "\($0)-01-01" },
                posterPath: nil
            )
            _selectedTMDBMovie  = State(initialValue: movie)
            _selectedPosterData = State(initialValue: log.moviePosterData)
            _draftEnglishOverview = State(initialValue: log.movieSynopsisEn)
            _tmdbYearApplied    = State(initialValue: true)  // 既存レコードは上書きしない
        } else {
            _selectedTMDBMovie  = State(initialValue: nil)
            _selectedPosterData = State(initialValue: nil)
            _draftEnglishOverview = State(initialValue: nil)
            _tmdbYearApplied    = State(initialValue: false)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ViewingTypeToggle(selection: $viewingType)
                }

                Section("作品") {
                    HStack {
                        TextField("映画タイトル", text: $movieTitle)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: movieTitle) { _, newValue in
                                onTitleChanged(newValue)
                            }
                        if !movieTitle.isEmpty {
                            Button {
                                clearTitleSearch()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        ForEach(searchResults.prefix(5)) { movie in
                            Button {
                                selectMovie(movie)
                            } label: {
                                TMDBMovieRow(movie: movie)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let movie = selectedTMDBMovie {
                        TMDBSelectedMovieCard(
                            movie: movie,
                            posterData: selectedPosterData,
                            onClear: {
                                detailTask?.cancel()
                                selectedTMDBMovie = nil
                                selectedPosterData = nil
                                draftMetadata = nil
                                draftEnglishOverview = nil
                                searchResults = []
                                tmdbYearApplied = false
                            }
                        )
                    }

                    if viewingType == .theater {
                        dateSection
                    }
                }

                if viewingType == .theater {
                    Section("映画館") {
                        HStack {
                            TextField("映画館名", text: $theaterName)
                            if hasTheaterInfo {
                                Button {
                                    clearTheater()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        TextField("スクリーン番号", text: $screenNumber)
                        TextField("座席番号", text: $seatNumber)
                        LabeledContent("料金") {
                            TextField("0", text: $admissionFeeText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        Picker("上映形式", selection: $screeningFormat) {
                            ForEach(ScreeningFormat.allCases, id: \.self) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        TextField("メモ", text: $theaterMemo)
                    }
                } else {
                    Section("視聴日") {
                        dateSection
                        if watchedDateMode == .full {
                            ForEach($additionalDates) { $item in
                                HStack {
                                    DatePicker("", selection: $item.date, displayedComponents: .date)
                                        .labelsHidden()
                                    Spacer()
                                    Button {
                                        additionalDates.removeAll { $0.id == item.id }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            Button {
                                additionalDates.append(IdentifiableDate(date: Date()))
                            } label: {
                                Label("視聴日を追加", systemImage: "plus.circle")
                            }
                        }
                        Picker("メディア", selection: $streamingService) {
                            ForEach(streamingStore.services, id: \.self) { service in
                                Text(service).tag(service)
                            }
                            Text(StreamingServiceStore.otherOption)
                                .tag(StreamingServiceStore.otherOption)
                        }
                        if streamingService == StreamingServiceStore.otherOption {
                            TextField("サービス名", text: $customStreamingService)
                        }
                    }
                }

                Section("評価") {
                    HStack {
                        StarRatingView(rating: rating, editing: true) { selected in
                            rating = selected
                        }
                        Spacer()
                        if rating != nil {
                            Button("クリア") { rating = nil }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("感想") {
                    TextField("感想を書く...", text: $review, axis: .vertical)
                        .lineLimit(5...10)
                        .keyboardCloseToolbar()
                }

                if viewingType == .theater {
                    Section("チケット画像") {
                        PhotosPicker(selection: $selectedTicketItems, matching: .images) {
                            Label("画像を追加", systemImage: "plus.circle")
                        }
                        Button {
                            pasteFromClipboard()
                        } label: {
                            Label("クリップボードから貼り付け", systemImage: "doc.on.clipboard")
                        }
                        if !log.ticketImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(log.ticketImages) { ticket in
                                        if let uiImage = UIImage(data: ticket.imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipped()
                                                .cornerRadius(CornerRadius.standard)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(movieTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if viewingType == .theater {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            Task { await rescan() }
                        } label: {
                            if isScanning {
                                HStack(spacing: 6) {
                                    ProgressView()
                                    Text("読み取り中...")
                                }
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("画像を再読み取り")
                                }
                            }
                        }
                        .disabled(isScanning)
                    }
                }
            }
            .onChange(of: selectedTicketItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    await addTicketImages(newItems)
                    selectedTicketItems = []
                }
            }
            .sheet(isPresented: $showOCRSheet) {
                if let result = ocrResult {
                    OCRResultSheet(result: result) { field in
                        applyOCRField(field)
                    }
                }
            }
            .alert("読み取れませんでした", isPresented: $showRescanEmptyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("チケット画像から情報を読み取れませんでした。")
            }
            .alert("クリップボードに画像がありません", isPresented: $showNoPasteImageAlert) {
                Button("OK", role: .cancel) {}
            }
            .onChange(of: watchedDateMode) { _, newMode in
                guard newMode == .yearOnly,
                      !tmdbYearApplied,
                      let releaseYear = selectedTMDBMovie?.releaseYear
                else { return }
                watchedYear = releaseYear
                tmdbYearApplied = true
            }
        }
    }

    // MARK: - Date section

    @ViewBuilder
    private var dateSection: some View {
        Picker("日付精度", selection: $watchedDateMode) {
            ForEach(WatchedDateMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }

        switch watchedDateMode {
        case .full:
            DatePicker(
                viewingType == .theater ? "観た日" : "初回",
                selection: $watchedAt,
                displayedComponents: .date
            )
        case .yearOnly:
            Stepper("\(watchedYear)年", value: $watchedYear, in: 1900...Self.currentYear)
        case .unknown:
            EmptyView()
        }
    }

    // MARK: - TMDB search

    private func onTitleChanged(_ newValue: String) {
        if let selected = selectedTMDBMovie, newValue != selected.title {
            posterTask?.cancel()
            detailTask?.cancel()
            selectedTMDBMovie = nil
            selectedPosterData = nil
            draftMetadata = nil
            draftEnglishOverview = nil
            searchResults = []
        }
        guard selectedTMDBMovie == nil else { return }
        searchTask?.cancel()
        guard newValue.count >= 2 else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            isSearching = true
            defer { isSearching = false }
            searchResults = (try? await TMDBClient.search(query: newValue)) ?? []
        }
    }

    private func selectMovie(_ movie: TMDBMovie) {
        searchTask?.cancel()
        selectedTMDBMovie = movie
        movieTitle = movie.title
        searchResults = []
        tmdbYearApplied = false
        if watchedDateMode == .yearOnly, let releaseYear = movie.releaseYear {
            watchedYear = releaseYear
            tmdbYearApplied = true
        }
        let capturedID = movie.id
        draftMetadata = nil
        draftEnglishOverview = nil
        posterTask?.cancel()
        posterTask = Task {
            guard let posterPath = movie.posterPath else { return }
            let data = try? await TMDBClient.fetchPosterData(path: posterPath)
            guard !Task.isCancelled, selectedTMDBMovie?.id == capturedID else { return }
            selectedPosterData = data
        }
        // Silent background detail fetch — failures are independent and non-fatal
        detailTask?.cancel()
        detailTask = Task {
            async let metadata = try? TMDBClient.fetchMovieDetails(id: capturedID)
            async let englishOverview = try? TMDBClient.fetchEnglishOverview(id: capturedID)
            let (metadataResult, overviewResult) = await (metadata, englishOverview)
            guard !Task.isCancelled, selectedTMDBMovie?.id == capturedID else { return }
            draftMetadata = metadataResult
            draftEnglishOverview = overviewResult?.isEmpty == false ? overviewResult : nil
        }
    }

    private func clearTitleSearch() {
        searchTask?.cancel()
        posterTask?.cancel()
        detailTask?.cancel()
        selectedTMDBMovie = nil
        selectedPosterData = nil
        draftMetadata = nil
        draftEnglishOverview = nil
        searchResults = []
        movieTitle = ""
        tmdbYearApplied = false
    }

    private var hasTheaterInfo: Bool {
        !theaterName.isEmpty || !screenNumber.isEmpty
            || !seatNumber.isEmpty || !admissionFeeText.isEmpty
            || screeningFormat != .standard || !theaterMemo.isEmpty
    }

    private func clearTheater() {
        theaterName      = ""
        screenNumber     = ""
        seatNumber       = ""
        admissionFeeText = ""
        screeningFormat  = .standard
        theaterMemo      = ""
    }

    // MARK: - Clipboard

    private func pasteFromClipboard() {
        guard let image = UIPasteboard.general.image,
              let data = image.jpegData(compressionQuality: Self.pasteJPEGQuality) else {
            showNoPasteImageAlert = true
            return
        }
        Task {
            let ticket = TicketImage(imageData: data)
            ticket.ocrRawText = await OCRService.recognizeText(from: data)
            context.insert(ticket)
            log.ticketImages.append(ticket)
            log.updatedAt = Date()
        }
    }

    // MARK: - Ticket scan

    private func addTicketImages(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let ticket = TicketImage(imageData: data)
            ticket.ocrRawText = await OCRService.recognizeText(from: data)
            context.insert(ticket)
            log.ticketImages.append(ticket)
        }
        log.updatedAt = Date()
        await rescan()
    }

    private func rescan() async {
        isScanning = true
        defer { isScanning = false }

        var merged = CinemaTicketResult()
        for ticket in log.ticketImages {
            let rawText: String?
            if let existing = ticket.ocrRawText {
                rawText = existing
            } else {
                rawText = await OCRService.recognizeText(from: ticket.imageData)
            }
            guard let rawText else { continue }
            let parsed = CinemaTicketParser.parse(rawText)
            if merged.movieTitle == nil     { merged.movieTitle = parsed.movieTitle }
            if merged.theaterName == nil    { merged.theaterName = parsed.theaterName }
            if merged.screenNumber == nil   { merged.screenNumber = parsed.screenNumber }
            if merged.seatNumber == nil     { merged.seatNumber = parsed.seatNumber }
            if merged.watchedAt == nil      { merged.watchedAt = parsed.watchedAt }
            if merged.screeningFormat == nil { merged.screeningFormat = parsed.screeningFormat }
            if merged.admissionFee == nil   { merged.admissionFee = parsed.admissionFee }
        }
        ocrResult = merged
        if merged.hasAnyResult {
            showOCRSheet = true
        } else {
            showRescanEmptyAlert = true
        }
    }

    private func applyOCRField(_ field: OCRResultSheet.OCRField) {
        switch field {
        case .movieTitle(let v):      movieTitle = v
        case .theaterName(let v):     theaterName = v
        case .screenNumber(let v):    screenNumber = v
        case .seatNumber(let v):      seatNumber = v
        case .watchedAt(let v):       watchedAt = v; watchedDateMode = .full
        case .screeningFormat(let v): screeningFormat = v
        case .admissionFee(let v):    admissionFeeText = String(v)
        }
    }

    // MARK: - Save

    private func saveChanges() {
        log.movieTitle       = movieTitle.trimmingCharacters(in: .whitespaces)
        log.watchedAtUnknown = watchedDateMode == .unknown
        log.watchedYearOnly  = watchedDateMode == .yearOnly
        log.watchedAt        = resolvedWatchedAt
        log.rating           = rating
        log.viewingType      = viewingType.rawValue
        log.review           = review.trimmingCharacters(in: .whitespaces)
        log.updatedAt        = Date()

        if viewingType == .theater {
            log.theaterName     = theaterName.trimmingCharacters(in: .whitespaces)
            log.theaterMemo     = theaterMemo.trimmingCharacters(in: .whitespaces)
            log.screenNumber    = screenNumber.isEmpty ? nil : screenNumber
            log.seatNumber      = seatNumber.isEmpty ? nil : seatNumber
            log.screeningFormat = screeningFormat.rawValue
            log.admissionFee = admissionFeeText.isEmpty ? nil : Int(admissionFeeText.filter { $0.isNumber })
            log.streamingService = nil
            // 映画館に切り替えた場合、配信日付を削除
            for vd in log.viewingDates { context.delete(vd) }
        } else {
            let service = streamingService == StreamingServiceStore.otherOption
                ? customStreamingService
                : streamingService
            log.streamingService = service.isEmpty ? nil : service
            log.theaterName     = ""
            log.theaterMemo     = ""
            log.screenNumber    = nil
            log.seatNumber      = nil

            // 追加視聴日を書き戻し
            if watchedDateMode == .full {
                // UUID を維持した upsert
                let existingByID = Dictionary(uniqueKeysWithValues: log.viewingDates.map { ($0.id, $0) })
                let newIDs = Set(additionalDates.map { $0.id })
                for vd in log.viewingDates where !newIDs.contains(vd.id) {
                    context.delete(vd)
                }
                for item in additionalDates {
                    if let existing = existingByID[item.id] {
                        existing.date = item.date
                    } else {
                        let vd = ViewingDate(date: item.date)
                        vd.id = item.id
                        context.insert(vd)
                        log.viewingDates.append(vd)
                    }
                }
            } else {
                // yearOnly / unknown: 視聴日は不要なので全削除
                for vd in log.viewingDates { context.delete(vd) }
            }
        }

        // TMDB
        if let movie = selectedTMDBMovie {
            log.tmdbId = movie.id
            log.movieOriginalTitle = movie.originalTitle != movie.title ? movie.originalTitle : nil
            log.movieReleaseYear = movie.releaseYear
            log.movieSynopsis = movie.overview.isEmpty ? nil : movie.overview
            log.movieSynopsisEn = draftEnglishOverview
            log.moviePosterData = selectedPosterData ?? log.moviePosterData
            // Phase 1: re-select 時のみ extended metadata を更新する
            if let metadata = draftMetadata {
                log.movieRuntimeMinutes = metadata.runtimeMinutes
                log.movieGenresRaw = metadata.genres.isEmpty ? nil : metadata.genres.joined(separator: ",")
                log.movieDirector = metadata.director
                log.movieCastRaw = metadata.topCast.isEmpty ? nil : metadata.topCast.joined(separator: ",")
                log.metadataUpdatedAt = Date()
            }
        } else {
            log.tmdbId = nil
            log.movieOriginalTitle = nil
            log.movieReleaseYear = nil
            log.movieSynopsis = nil
            log.movieSynopsisEn = nil
            log.moviePosterData = nil
            // TMDB リンクを削除したら extended metadata も合わせてクリア
            log.movieRuntimeMinutes = nil
            log.movieGenresRaw = nil
            log.movieDirector = nil
            log.movieCastRaw = nil
            log.metadataUpdatedAt = nil
        }
    }

    private var resolvedWatchedAt: Date {
        switch watchedDateMode {
        case .full:
            return watchedAt
        case .yearOnly:
            return Calendar.current.date(from: DateComponents(year: watchedYear, month: 1, day: 1)) ?? Date()
        case .unknown:
            return Date()
        }
    }
}

// MARK: - Private subviews
