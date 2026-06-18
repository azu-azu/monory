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

    // Viewing type
    var viewingType: String = ViewingType.theater.rawValue
    var streamingService: String?

    // TMDB
    var tmdbId: Int?
    var movieOriginalTitle: String?
    var movieReleaseYear: Int?
    var movieSynopsis: String?

    @Attribute(.externalStorage)
    var moviePosterData: Data?

    var watchedAtUnknown: Bool = false
    var rating: Int? = nil

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \TicketImage.movieLog)
    var ticketImages: [TicketImage] = []

    /// 配信時の追加視聴日（watchedAt が初回日、以降はここに追加）
    @Relationship(deleteRule: .cascade, inverse: \ViewingDate.movieLog)
    var viewingDates: [ViewingDate] = []

    var isStreaming: Bool {
        viewingType == ViewingType.streaming.rawValue
    }

    var isUpcoming: Bool {
        guard !watchedAtUnknown else { return false }
        return Calendar.current.startOfDay(for: watchedAt) > Calendar.current.startOfDay(for: Date())
    }

    var watchedAtDisplay: String {
        watchedAtUnknown
            ? "不明"
            : watchedAt.formatted(date: .long, time: .omitted)
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
