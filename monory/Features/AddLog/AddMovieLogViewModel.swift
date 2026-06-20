import SwiftUI
import SwiftData
import PhotosUI

struct TicketImageDraft: Identifiable {
    let id: UUID = UUID()
    let imageData: Data
    var ocrRawText: String?
}

struct IdentifiableDate: Identifiable {
    let id: UUID = UUID()
    var date: Date
}

enum WatchedDateMode: String, CaseIterable {
    case full     = "日付"
    case yearOnly = "年のみ"
    case unknown  = "不明"
}

@MainActor
@Observable
final class AddMovieLogViewModel {
    // Viewing type
    static let otherServiceOption = StreamingServiceStore.otherOption
    // OCR ノイズが末尾に集中するため、前半N文字のみで TMDB 検索する
    private static let ocrSearchPrefixLength = 15
    private static let currentYear = Calendar.current.component(.year, from: Date())

    var viewingType: ViewingType
    var scannedFromTicket: Bool = false
    var streamingService: String = StreamingServiceStore.loadServices().first ?? StreamingServiceStore.defaultServices[0]
    var customStreamingService: String = ""

    // メディア: 2回目以降の視聴日
    var additionalDates: [IdentifiableDate] = []

    var effectiveStreamingService: String {
        streamingService == Self.otherServiceOption ? customStreamingService : streamingService
    }

    var movieTitle: String = ""
    var watchedAt: Date = Date()
    var watchedDateMode: WatchedDateMode = .full
    var watchedYear: Int = Calendar.current.component(.year, from: Date())
    var theaterName: String = ""
    var theaterMemo: String = ""
    var screenNumber: String = ""
    var seatNumber: String = ""
    var screeningFormat: ScreeningFormat = .standard
    var admissionFeeText: String = ""
    var rating: Int? = nil
    var review: String = ""
    var ticketDrafts: [TicketImageDraft] = []

    // TMDB search
    var searchResults: [TMDBMovie] = []
    var isSearching = false
    var selectedTMDBMovie: TMDBMovie?
    var selectedPosterData: Data?

    private var searchTask: Task<Void, Never>?

    init(initialViewingType: ViewingType = .theater) {
        self.viewingType = initialViewingType
    }

    var canSave: Bool {
        !movieTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var hasTheaterInfo: Bool {
        !theaterName.isEmpty || !screenNumber.isEmpty
            || !seatNumber.isEmpty || !admissionFeeText.isEmpty
            || screeningFormat != .standard || !theaterMemo.isEmpty
    }

    // MARK: - Ticket image + OCR

    func loadAndAddTicketImages(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await addTicketImage(data)
            }
        }
    }

    func addTicketImage(_ data: Data) async {
        let draft = TicketImageDraft(imageData: data)
        ticketDrafts.append(draft)

        let rawText = await OCRService.recognizeText(from: data)
        guard let i = ticketDrafts.firstIndex(where: { $0.id == draft.id }) else { return }
        ticketDrafts[i].ocrRawText = rawText

        guard let text = rawText else { return }
        scannedFromTicket = true
        watchedDateMode = .full
        let parsed = CinemaTicketParser.parse(text)
        applyOCRResult(parsed)

        // OCR 後に TMDB を即検索して先頭候補を auto-select
        // OCR ノイズが末尾に集中するため、前半N文字でマッチさせる
        guard selectedTMDBMovie == nil,
              let title = parsed.movieTitle, !title.isEmpty else { return }
        searchTask?.cancel()
        isSearching = true
        let shortQuery = String(title.prefix(Self.ocrSearchPrefixLength))
        let results = (try? await TMDBClient.search(query: shortQuery)) ?? []
        isSearching = false
        if let best = results.first {
            await selectMovie(best)
        } else {
            searchResults = results  // 結果なし → 手動検索に委ねる
        }
    }

    private func applyOCRResult(_ result: CinemaTicketResult) {
        if movieTitle.isEmpty, let v = result.movieTitle { movieTitle = v }
        if theaterName.isEmpty, let v = result.theaterName { theaterName = v }
        if screenNumber.isEmpty, let v = result.screenNumber { screenNumber = v }
        if seatNumber.isEmpty, let v = result.seatNumber { seatNumber = v }
        if admissionFeeText.isEmpty, let fee = result.admissionFee { admissionFeeText = String(fee) }
        if let date = result.watchedAt { watchedAt = date }
        if let format = result.screeningFormat,
           let sf = ScreeningFormat.allCases.first(where: { $0.rawValue == format }) {
            screeningFormat = sf
        }
    }

    // MARK: - TMDB search

    func onTitleChanged(_ newValue: String) {
        // 選択済みだが手動でタイトルを変更した場合、選択をクリアして再検索
        if let selected = selectedTMDBMovie, newValue != selected.title {
            clearSelection()
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

    func selectMovie(_ movie: TMDBMovie) async {
        selectedTMDBMovie = movie
        movieTitle = movie.title
        searchResults = []
        if let posterPath = movie.posterPath {
            selectedPosterData = try? await TMDBClient.fetchPosterData(path: posterPath)
        }
    }

    func clearSelection() {
        selectedTMDBMovie = nil
        selectedPosterData = nil
        searchResults = []
    }

    /// タイトル × ボタン用: 作品名と TMDB 選択のみリセット
    func clearTitle() {
        clearSelection()
        movieTitle = ""
        scannedFromTicket = false
        searchTask?.cancel()
    }

    /// 映画館 × ボタン用: 映画館情報のみリセット
    func clearTheater() {
        theaterName      = ""
        screenNumber     = ""
        seatNumber       = ""
        screeningFormat  = .standard
        admissionFeeText = ""
        theaterMemo      = ""
    }

    // MARK: - Save

    func save(in context: ModelContext) {
        let log = MovieLog(
            watchedAt: resolvedWatchedAt,
            movieTitle: movieTitle.trimmingCharacters(in: .whitespaces),
            theaterName: viewingType == .theater ? theaterName.trimmingCharacters(in: .whitespaces) : "",
            review: review.trimmingCharacters(in: .whitespaces)
        )
        log.watchedAtUnknown = watchedDateMode == .unknown
        log.watchedYearOnly  = watchedDateMode == .yearOnly
        log.rating = rating
        log.viewingType = viewingType.rawValue
        if viewingType == .theater {
            log.theaterMemo = theaterMemo.trimmingCharacters(in: .whitespaces)
            log.screenNumber = screenNumber.isEmpty ? nil : screenNumber
            log.seatNumber = seatNumber.isEmpty ? nil : seatNumber
            log.screeningFormat = screeningFormat.rawValue
            log.admissionFee = admissionFeeText.isEmpty ? nil : Int(admissionFeeText.filter { $0.isNumber })
        } else {
            let service = effectiveStreamingService
            log.streamingService = service.isEmpty ? nil : service
        }

        if let movie = selectedTMDBMovie {
            log.tmdbId = movie.id
            log.movieOriginalTitle = movie.originalTitle != movie.title ? movie.originalTitle : nil
            log.movieReleaseYear = movie.releaseYear
            log.movieSynopsis = movie.overview.isEmpty ? nil : movie.overview
            log.moviePosterData = selectedPosterData
        }

        context.insert(log)

        // メディア: 追加視聴日を保存
        if viewingType == .media {
            for item in additionalDates {
                let vd = ViewingDate(date: item.date)
                context.insert(vd)
                log.viewingDates.append(vd)
            }
        }

        for draft in ticketDrafts {
            let ticket = TicketImage(imageData: draft.imageData)
            ticket.ocrRawText = draft.ocrRawText
            log.ticketImages.append(ticket)
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
