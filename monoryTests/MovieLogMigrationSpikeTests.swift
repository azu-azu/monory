/// Phase 0 spike: MovieLog に Phase 1 field を追加したとき、既存 record が壊れないことを検証する。
/// in-memory store での動作確認。実デバイスの migration は Manual Verification で別途確認する。
import XCTest
import SwiftData
@testable import monory

final class MovieLogMigrationSpikeTests: XCTestCase {

    @MainActor
    private func makeContext() throws -> ModelContext {
        // ViewingDate は Schema に明示しなくても @Relationship 経由で含まれる。
        // AppContainer と同じ Schema 定義で挙動を確認する。
        let schema = Schema([MovieLog.self, TicketImage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - 既存 field の保持

    @MainActor
    func testExistingFieldsIntactAfterNewFieldsAdded() throws {
        let context = try makeContext()

        let log = MovieLog(
            watchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            movieTitle: "七人の侍",
            theaterName: "新宿バルト9",
            review: "傑作"
        )
        log.tmdbId = 11
        log.movieOriginalTitle = "Seven Samurai"
        log.movieReleaseYear = 1954
        log.rating = 5
        context.insert(log)
        try context.save()

        let record = try context.fetch(FetchDescriptor<MovieLog>()).first!
        XCTAssertEqual(record.movieTitle, "七人の侍")
        XCTAssertEqual(record.tmdbId, 11)
        XCTAssertEqual(record.movieOriginalTitle, "Seven Samurai")
        XCTAssertEqual(record.movieReleaseYear, 1954)
        XCTAssertEqual(record.rating, 5)
    }

    // MARK: - 新 field は nil（未取得）として扱われる

    @MainActor
    func testNewFieldsAreNilForExistingRecords() throws {
        let context = try makeContext()

        let log = MovieLog(watchedAt: Date(), movieTitle: "Test", theaterName: "", review: "")
        context.insert(log)
        try context.save()

        let record = try context.fetch(FetchDescriptor<MovieLog>()).first!
        XCTAssertNil(record.movieRuntimeMinutes, "未取得の record は nil")
        XCTAssertNil(record.movieGenresRaw, "未取得の record は nil")
        XCTAssertNil(record.movieDirector, "未取得の record は nil")
        XCTAssertNil(record.movieCastRaw, "未取得の record は nil")
        XCTAssertNil(record.metadataUpdatedAt, "未取得の record は nil")
    }

    // MARK: - computed property: nil / "" はどちらも []

    @MainActor
    func testComputedPropertiesNilAndEmptyBothReturnEmptyArray() throws {
        let context = try makeContext()

        let log = MovieLog(watchedAt: Date(), movieTitle: "Test", theaterName: "", review: "")
        context.insert(log)
        try context.save()

        let record = try context.fetch(FetchDescriptor<MovieLog>()).first!

        // nil → []
        XCTAssertEqual(record.movieGenres, [])
        XCTAssertEqual(record.movieCast, [])

        // "" → []
        record.movieGenresRaw = ""
        record.movieCastRaw = ""
        XCTAssertEqual(record.movieGenres, [])
        XCTAssertEqual(record.movieCast, [])

        // non-empty → array
        record.movieGenresRaw = "Action,Drama"
        record.movieCastRaw = "Actor A,Actor B,Actor C"
        XCTAssertEqual(record.movieGenres, ["Action", "Drama"])
        XCTAssertEqual(record.movieCast, ["Actor A", "Actor B", "Actor C"])
    }

    // MARK: - Phase 1 field の save / load

    @MainActor
    func testPhase1FieldsSaveAndLoad() throws {
        let context = try makeContext()

        let log = MovieLog(watchedAt: Date(), movieTitle: "Inception", theaterName: "", review: "")
        log.tmdbId = 27205
        log.movieRuntimeMinutes = 148
        log.movieGenresRaw = "Action,Science Fiction,Adventure"
        log.movieDirector = "Christopher Nolan"
        log.movieCastRaw = "Leonardo DiCaprio,Joseph Gordon-Levitt,Elliot Page,Tom Hardy,Ken Watanabe"
        log.metadataUpdatedAt = Date()
        context.insert(log)
        try context.save()

        let record = try context.fetch(FetchDescriptor<MovieLog>()).first!
        XCTAssertEqual(record.movieRuntimeMinutes, 148)
        XCTAssertEqual(record.movieGenres, ["Action", "Science Fiction", "Adventure"])
        XCTAssertEqual(record.movieDirector, "Christopher Nolan")
        XCTAssertEqual(record.movieCast.count, 5)
        XCTAssertEqual(record.movieCast.first, "Leonardo DiCaprio")
        XCTAssertNotNil(record.metadataUpdatedAt)
    }

    // MARK: - cast は上位 5 人に絞られていること

    @MainActor
    func testCastStoredAsTop5Only() throws {
        let context = try makeContext()

        let fullCast = ["A", "B", "C", "D", "E", "F", "G", "H"]
        let top5 = Array(fullCast.prefix(5))

        let log = MovieLog(watchedAt: Date(), movieTitle: "Test", theaterName: "", review: "")
        log.movieCastRaw = top5.joined(separator: ",")
        context.insert(log)
        try context.save()

        let record = try context.fetch(FetchDescriptor<MovieLog>()).first!
        XCTAssertEqual(record.movieCast.count, 5)
        XCTAssertEqual(record.movieCast, top5)
    }

    // MARK: - ViewingDate relationship は migration 後も動作する

    @MainActor
    func testViewingDateRelationshipAfterNewFields() throws {
        let context = try makeContext()

        let log = MovieLog(watchedAt: Date(), movieTitle: "Test", theaterName: "", review: "")
        log.viewingType = "media"
        context.insert(log)

        let date1 = ViewingDate(date: Date())
        let date2 = ViewingDate(date: Date().addingTimeInterval(86400))
        context.insert(date1)
        context.insert(date2)
        log.viewingDates.append(date1)
        log.viewingDates.append(date2)
        try context.save()

        let record = try context.fetch(FetchDescriptor<MovieLog>()).first!
        XCTAssertEqual(record.viewingDates.count, 2)
    }

    // MARK: - tmdbId == nil の record は metadata field も全て nil

    @MainActor
    func testNonTMDBRecordHasNilMetadata() throws {
        let context = try makeContext()

        let log = MovieLog(watchedAt: Date(), movieTitle: "手書きログ", theaterName: "自宅", review: "")
        context.insert(log)
        try context.save()

        let record = try context.fetch(FetchDescriptor<MovieLog>()).first!
        XCTAssertNil(record.tmdbId)
        XCTAssertNil(record.movieGenresRaw)
        XCTAssertNil(record.movieDirector)
        XCTAssertNil(record.metadataUpdatedAt)
    }
}
