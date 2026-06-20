/// Phase 1: TMDB detail / credits / external_ids DTO の decoding を検証する。
/// fixture は実際の TMDB API レスポンス構造に準拠した最小 JSON。
import XCTest
@testable import monory

final class TMDBDetailDecodingTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - Fixtures

    /// 正常系: 全フィールドあり
    private let fullResponseJSON = """
    {
      "id": 27205,
      "runtime": 148,
      "vote_average": 8.4,
      "vote_count": 36000,
      "revenue": 836836967,
      "genres": [
        { "id": 28, "name": "Action" },
        { "id": 878, "name": "Science Fiction" }
      ],
      "credits": {
        "cast": [
          { "name": "Leonardo DiCaprio", "order": 0 },
          { "name": "Joseph Gordon-Levitt", "order": 1 },
          { "name": "Elliot Page", "order": 2 },
          { "name": "Tom Hardy", "order": 3 },
          { "name": "Ken Watanabe", "order": 4 },
          { "name": "Cillian Murphy", "order": 5 },
          { "name": "Marion Cotillard", "order": 6 }
        ],
        "crew": [
          { "name": "Christopher Nolan", "job": "Director" },
          { "name": "Emma Thomas", "job": "Producer" }
        ]
      },
      "external_ids": {
        "wikidata_id": "Q25188"
      }
    }
    """.data(using: .utf8)!

    /// revenue が 0（不明）の場合
    private let zeroRevenueJSON = """
    {
      "id": 999,
      "runtime": 90,
      "vote_average": 7.0,
      "vote_count": 100,
      "revenue": 0,
      "genres": [],
      "credits": { "cast": [], "crew": [] },
      "external_ids": {}
    }
    """.data(using: .utf8)!

    /// cast と crew が空の場合
    private let emptyCreditsJSON = """
    {
      "id": 1,
      "runtime": null,
      "vote_average": null,
      "vote_count": null,
      "revenue": null,
      "genres": [],
      "credits": { "cast": [], "crew": [] },
      "external_ids": { "wikidata_id": null }
    }
    """.data(using: .utf8)!

    /// director が複数いる場合（co-director）
    private let multipleDirectorsJSON = """
    {
      "id": 2,
      "runtime": 120,
      "vote_average": 8.0,
      "vote_count": 5000,
      "revenue": 1000000,
      "genres": [{ "id": 18, "name": "Drama" }],
      "credits": {
        "cast": [{ "name": "Actor A", "order": 0 }],
        "crew": [
          { "name": "Director A", "job": "Director" },
          { "name": "Director B", "job": "Director" },
          { "name": "Producer X", "job": "Producer" }
        ]
      },
      "external_ids": {}
    }
    """.data(using: .utf8)!

    // MARK: - TMDBDetailResponse decoding

    func testFullResponseDecoding() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: fullResponseJSON)
        XCTAssertEqual(dto.id, 27205)
        XCTAssertEqual(dto.runtime, 148)
        XCTAssertEqual(dto.voteAverage ?? 0, 8.4, accuracy: 0.01)
        XCTAssertEqual(dto.voteCount, 36000)
        XCTAssertEqual(dto.revenue, 836836967)
        XCTAssertEqual(dto.genres.count, 2)
        XCTAssertEqual(dto.genres[0].name, "Action")
        XCTAssertEqual(dto.genres[1].name, "Science Fiction")
        XCTAssertEqual(dto.credits.cast.count, 7)
        XCTAssertEqual(dto.credits.crew.count, 2)
        XCTAssertEqual(dto.externalIDs.wikidataID, "Q25188")
    }

    func testCastOrderPreserved() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: fullResponseJSON)
        XCTAssertEqual(dto.credits.cast[0].name, "Leonardo DiCaprio")
        XCTAssertEqual(dto.credits.cast[0].order, 0)
        XCTAssertEqual(dto.credits.cast[4].name, "Ken Watanabe")
        XCTAssertEqual(dto.credits.cast[4].order, 4)
    }

    func testDirectorExtracted() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: fullResponseJSON)
        let director = dto.credits.crew.first(where: { $0.job == "Director" })
        XCTAssertEqual(director?.name, "Christopher Nolan")
    }

    func testZeroRevenueDecoding() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: zeroRevenueJSON)
        XCTAssertEqual(dto.revenue, 0)
    }

    func testNullFieldsDecoding() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: emptyCreditsJSON)
        XCTAssertNil(dto.runtime)
        XCTAssertNil(dto.voteAverage)
        XCTAssertNil(dto.voteCount)
        XCTAssertNil(dto.revenue)
        XCTAssertTrue(dto.genres.isEmpty)
        XCTAssertTrue(dto.credits.cast.isEmpty)
        XCTAssertTrue(dto.credits.crew.isEmpty)
        XCTAssertNil(dto.externalIDs.wikidataID)
    }

    func testMultipleDirectorsFirstIsUsed() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: multipleDirectorsJSON)
        let directors = dto.credits.crew.filter { $0.job == "Director" }
        XCTAssertEqual(directors.count, 2)
        // mapping では最初の Director を使う
        XCTAssertEqual(directors.first?.name, "Director A")
    }

    // MARK: - append_to_response の未知フィールドを無視する

    func testUnknownTopLevelFieldsIgnored() throws {
        let json = """
        {
          "id": 1,
          "title": "Test Movie",
          "overview": "An overview",
          "runtime": 100,
          "vote_average": 7.5,
          "vote_count": 200,
          "revenue": 0,
          "genres": [],
          "credits": { "cast": [], "crew": [] },
          "external_ids": {},
          "release_dates": { "results": [] },
          "watch/providers": { "results": {} },
          "popularity": 123.4,
          "status": "Released"
        }
        """.data(using: .utf8)!

        XCTAssertNoThrow(try decoder.decode(TMDBDetailResponse.self, from: json))
    }
}
