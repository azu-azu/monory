import SwiftUI
import SwiftData
import PhotosUI

struct TicketImageDraft: Identifiable {
    let id: UUID = UUID()
    let imageData: Data
    var ocrRawText: String?
}

@MainActor
@Observable
final class AddMovieLogViewModel {
    // Viewing type
    static let otherServiceOption = "その他"
    static let streamingServices: [String] = [
        "Netflix", "Prime Video", "Disney+", "Apple TV+",
        "U-NEXT", "Hulu", "dアニメストア", "ABEMA", otherServiceOption,
    ]

    var viewingType: ViewingType = .theater
    var streamingService: String = "Netflix"
    var customStreamingService: String = ""

    var effectiveStreamingService: String {
        streamingService == Self.otherServiceOption ? customStreamingService : streamingService
    }

    var movieTitle: String = ""
    var watchedAt: Date = Date()
    var theaterName: String = ""
    var screenNumber: String = ""
    var seatNumber: String = ""
    var screeningFormat: ScreeningFormat = .standard
    var review: String = ""
    var ticketDrafts: [TicketImageDraft] = []

    // TMDB search
    var searchResults: [TMDBMovie] = []
    var isSearching = false
    var selectedTMDBMovie: TMDBMovie?
    var selectedPosterData: Data?

    private var searchTask: Task<Void, Never>?

    var canSave: Bool {
        !movieTitle.trimmingCharacters(in: .whitespaces).isEmpty
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
        let idx = ticketDrafts.count
        ticketDrafts.append(TicketImageDraft(imageData: data))

        let rawText = await OCRService.recognizeText(from: data)
        ticketDrafts[idx].ocrRawText = rawText

        if let text = rawText {
            applyOCRResult(CinemaTicketParser.parse(text))
        }
    }

    private func applyOCRResult(_ result: CinemaTicketResult) {
        if movieTitle.isEmpty, let v = result.movieTitle { movieTitle = v }
        if theaterName.isEmpty, let v = result.theaterName { theaterName = v }
        if screenNumber.isEmpty, let v = result.screenNumber { screenNumber = v }
        if seatNumber.isEmpty, let v = result.seatNumber { seatNumber = v }
        if let date = result.watchedAt { watchedAt = date }
        if let format = result.screeningFormat,
           let sf = ScreeningFormat.allCases.first(where: { $0.rawValue == format }) {
            screeningFormat = sf
        }
    }

    // MARK: - TMDB search

    func onTitleChanged(_ newValue: String) {
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

    // MARK: - Save

    func save(in context: ModelContext) {
        let log = MovieLog(
            watchedAt: watchedAt,
            movieTitle: movieTitle.trimmingCharacters(in: .whitespaces),
            theaterName: viewingType == .theater ? theaterName.trimmingCharacters(in: .whitespaces) : "",
            review: review.trimmingCharacters(in: .whitespaces)
        )
        log.viewingType = viewingType.rawValue
        if viewingType == .theater {
            log.screenNumber = screenNumber.isEmpty ? nil : screenNumber
            log.seatNumber = seatNumber.isEmpty ? nil : seatNumber
            log.screeningFormat = screeningFormat.rawValue
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

        for draft in ticketDrafts {
            let ticket = TicketImage(imageData: draft.imageData)
            ticket.ocrRawText = draft.ocrRawText
            log.ticketImages.append(ticket)
        }
    }
}
