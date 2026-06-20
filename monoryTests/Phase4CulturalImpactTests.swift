/// Phase 4: 文化的インパクト field の persist / export / import を検証する。
import XCTest
@testable import monory

final class Phase4CulturalImpactTests: XCTestCase {

    // MARK: - MovieLog field tests

    func testCulturalImpactNoteDefaultsToEmpty() {
        let log = MovieLog(watchedAt: .now, movieTitle: "Test", theaterName: "", review: "")
        XCTAssertEqual(log.culturalImpactNote, "")
    }

    func testCulturalImpactSourcesDefaultsToEmpty() {
        let log = MovieLog(watchedAt: .now, movieTitle: "Test", theaterName: "", review: "")
        XCTAssertTrue(log.culturalImpactSources.isEmpty)
    }

    func testCulturalImpactSourcesRoundTrip() throws {
        let log = MovieLog(watchedAt: .now, movieTitle: "Test", theaterName: "", review: "")
        let urlStrings = ["https://en.wikipedia.org/wiki/Inception", "https://www.rottentomatoes.com/m/inception"]
        log.culturalImpactSourcesData = try JSONEncoder().encode(urlStrings)
        let sources = log.culturalImpactSources
        XCTAssertEqual(sources.count, 2)
        XCTAssertEqual(sources[0].absoluteString, urlStrings[0])
        XCTAssertEqual(sources[1].absoluteString, urlStrings[1])
    }

    func testCulturalImpactSourcesFiltersInvalidURLs() throws {
        let log = MovieLog(watchedAt: .now, movieTitle: "Test", theaterName: "", review: "")
        let strings = ["https://valid.example.com", "not-a-url", "  "]
        log.culturalImpactSourcesData = try JSONEncoder().encode(strings)
        let sources = log.culturalImpactSources
        // "not-a-url" has no scheme → filtered; whitespace-only → filtered
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].absoluteString, "https://valid.example.com")
    }

    func testCulturalImpactSourcesNilDataReturnsEmpty() {
        let log = MovieLog(watchedAt: .now, movieTitle: "Test", theaterName: "", review: "")
        log.culturalImpactSourcesData = nil
        XCTAssertTrue(log.culturalImpactSources.isEmpty)
    }

    func testCulturalImpactSourcesTrimWhitespace() throws {
        let log = MovieLog(watchedAt: .now, movieTitle: "Test", theaterName: "", review: "")
        log.culturalImpactSourcesData = try JSONEncoder().encode(["  https://example.com  "])
        XCTAssertEqual(log.culturalImpactSources.first?.absoluteString, "https://example.com")
    }

    // MARK: - BackupDTO round-trip

    func testMovieLogDTOIncludesCulturalImpactFields() throws {
        let dto = MovieLogDTO(
            id: UUID().uuidString,
            watchedAt: .now,
            movieTitle: "Inception",
            theaterName: "",
            review: "",
            screenNumber: nil,
            seatNumber: nil,
            screeningFormat: "standard",
            admissionFee: nil,
            viewingType: "theater",
            streamingService: nil,
            tmdbId: nil,
            movieOriginalTitle: nil,
            movieReleaseYear: nil,
            movieSynopsis: nil,
            posterImageExt: nil,
            watchedAtUnknown: false,
            watchedYearOnly: false,
            theaterMemo: "",
            rating: nil,
            createdAt: .now,
            updatedAt: .now,
            ticketImages: [],
            viewingDates: [],
            culturalImpactNote: "映画の歴史に残る一作",
            culturalImpactSources: ["https://en.wikipedia.org/wiki/Inception"]
        )
        XCTAssertEqual(dto.culturalImpactNote, "映画の歴史に残る一作")
        XCTAssertEqual(dto.culturalImpactSources?.first, "https://en.wikipedia.org/wiki/Inception")
    }

    func testMovieLogDTOCulturalImpactOptionalIsNilForOldBackups() throws {
        // 旧バックアップ（culturalImpactNote/Sources なし）も decode できる
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "watchedAt": "2026-01-01T00:00:00Z",
          "movieTitle": "Old Movie",
          "theaterName": "",
          "review": "",
          "screeningFormat": "standard",
          "viewingType": "theater",
          "watchedAtUnknown": false,
          "watchedYearOnly": false,
          "theaterMemo": "",
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-01T00:00:00Z",
          "ticketImages": [],
          "viewingDates": []
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(MovieLogDTO.self, from: json)
        XCTAssertNil(dto.culturalImpactNote)
        XCTAssertNil(dto.culturalImpactSources)
    }

    // MARK: - CSV export

    func testCSVExportIncludesCulturalImpactColumns() throws {
        let log = MovieLog(watchedAt: .now, movieTitle: "Inception", theaterName: "", review: "")
        log.culturalImpactNote = "夢と現実の境界"
        log.culturalImpactSourcesData = try JSONEncoder().encode([
            "https://en.wikipedia.org/wiki/Inception",
            "https://www.imdb.com/title/tt1375666/"
        ])

        let data = MovieLogExporter.export(logs: [log])
        let csv = String(data: data.dropFirst(3), encoding: .utf8)! // drop BOM
        let lines = csv.components(separatedBy: "\r\n")
        let header = lines[0]
        let row = lines[1]

        XCTAssertTrue(header.contains("文化的インパクト"))
        XCTAssertTrue(header.contains("参考URL"))
        XCTAssertTrue(row.contains("夢と現実の境界"))
        // URLs joined with |
        XCTAssertTrue(row.contains("https://en.wikipedia.org/wiki/Inception|https://www.imdb.com/title/tt1375666/"))
    }

    func testCSVExportEmptyCulturalImpactProducesEmptyColumns() {
        let log = MovieLog(watchedAt: .now, movieTitle: "No Impact", theaterName: "", review: "")
        let data = MovieLogExporter.export(logs: [log])
        let csv = String(data: data.dropFirst(3), encoding: .utf8)!
        let row = csv.components(separatedBy: "\r\n")[1]
        // 末尾に ",," が含まれる（空フィールドが2つ）
        XCTAssertTrue(row.hasSuffix(",,"))
    }
}
