import SwiftData
import Foundation

@Model
final class MovieLog {
    var id: UUID = UUID()
    var watchedAt: Date = Date()

    var movieTitle: String = ""
    var theaterName: String = ""
    var review: String = ""

    var screenNumber: String?
    var seatNumber: String?
    var screeningFormat: String = ScreeningFormat.standard.rawValue
    var admissionFee: Int?

    // Viewing type
    var viewingType: String = ViewingType.theater.rawValue
    var streamingService: String?

    // TMDB — basic
    var tmdbId: Int?
    var movieOriginalTitle: String?
    var movieReleaseYear: Int?
    var movieSynopsis: String?
    var movieSynopsisEn: String?

    @Attribute(.externalStorage)
    var moviePosterData: Data?

    // TMDB — Phase 1 extended metadata
    // nil = 未取得, "" = 取得済みだが値なし, non-empty = 取得済み
    var movieRuntimeMinutes: Int?
    var movieGenresRaw: String?
    var movieDirector: String?
    var movieCastRaw: String?
    var metadataUpdatedAt: Date?

    var watchedAtUnknown: Bool = false
    var watchedYearOnly: Bool = false
    var theaterMemo: String = ""
    var rating: Int? = nil

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \TicketImage.movieLog)
    var ticketImages: [TicketImage] = []

    /// 配信時の追加視聴日（watchedAt が初回日、以降はここに追加）
    @Relationship(deleteRule: .cascade, inverse: \ViewingDate.movieLog)
    var viewingDates: [ViewingDate] = []

    /// nil / 空 string はどちらも [] に map する。View 側に persistence の意味論を漏らさない。
    var movieGenres: [String] {
        guard let raw = movieGenresRaw, !raw.isEmpty else { return [] }
        return raw.split(separator: ",").map(String.init)
    }

    var movieCast: [String] {
        guard let raw = movieCastRaw, !raw.isEmpty else { return [] }
        return raw.split(separator: ",").map(String.init)
    }

    var isMedia: Bool {
        viewingType == ViewingType.media.rawValue
    }

    var isUpcoming: Bool {
        guard !watchedAtUnknown else { return false }
        return Calendar.current.startOfDay(for: watchedAt) > Calendar.current.startOfDay(for: Date())
    }

    var displayTitle: String {
        movieTitle.isEmpty ? "無題" : movieTitle
    }

    var watchedAtDisplay: String {
        if watchedAtUnknown { return "不明" }
        if watchedYearOnly {
            return "\(Calendar.current.component(.year, from: watchedAt))年"
        }
        return watchedAt.formatted(date: .long, time: .omitted)
    }

    init(
        watchedAt: Date = Date(),
        movieTitle: String = "",
        theaterName: String = "",
        review: String = ""
    ) {
        self.watchedAt = watchedAt
        self.movieTitle = movieTitle
        self.theaterName = theaterName
        self.review = review
    }
}
