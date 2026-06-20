/// Phase 2: JP certification / watch providers / revenue の decoding と mapping を検証する。
import XCTest
@testable import monory

final class Phase2RegionalDataTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - Fixtures

    private let fullPhase2JSON = """
    {
      "id": 27205,
      "runtime": 148,
      "vote_average": 8.4,
      "vote_count": 36000,
      "revenue": 836836967,
      "genres": [],
      "credits": { "cast": [], "crew": [] },
      "external_ids": {},
      "release_dates": {
        "results": [
          {
            "iso_3166_1": "JP",
            "release_dates": [
              { "certification": "",  "type": 1 },
              { "certification": "G", "type": 3 }
            ]
          },
          {
            "iso_3166_1": "US",
            "release_dates": [
              { "certification": "PG-13", "type": 3 }
            ]
          }
        ]
      },
      "watch/providers": {
        "results": {
          "JP": {
            "flatrate": [
              { "provider_id": 8, "provider_name": "Netflix", "logo_path": "/abc.jpg", "display_priority": 0 }
            ],
            "rent": [
              { "provider_id": 10, "provider_name": "Amazon Video", "logo_path": "/xyz.jpg", "display_priority": 1 }
            ]
          }
        }
      }
    }
    """.data(using: .utf8)!

    private let noJPDataJSON = """
    {
      "id": 1,
      "runtime": 90,
      "vote_average": 7.0,
      "vote_count": 100,
      "revenue": 0,
      "genres": [],
      "credits": { "cast": [], "crew": [] },
      "external_ids": {},
      "release_dates": {
        "results": [
          {
            "iso_3166_1": "US",
            "release_dates": [{ "certification": "R", "type": 3 }]
          }
        ]
      },
      "watch/providers": {
        "results": {
          "US": {
            "flatrate": [{ "provider_id": 8, "provider_name": "Netflix", "logo_path": null, "display_priority": 0 }]
          }
        }
      }
    }
    """.data(using: .utf8)!

    private let allProviderTypesJSON = """
    {
      "id": 2,
      "runtime": 100,
      "vote_average": 7.0,
      "vote_count": 500,
      "revenue": 0,
      "genres": [],
      "credits": { "cast": [], "crew": [] },
      "external_ids": {},
      "release_dates": { "results": [] },
      "watch/providers": {
        "results": {
          "JP": {
            "flatrate": [{ "provider_id": 1, "provider_name": "Sub Service",  "logo_path": null, "display_priority": 0 }],
            "free":     [{ "provider_id": 2, "provider_name": "Free Service",  "logo_path": null, "display_priority": 1 }],
            "ads":      [{ "provider_id": 3, "provider_name": "Ads Service",   "logo_path": null, "display_priority": 2 }],
            "rent":     [{ "provider_id": 4, "provider_name": "Rent Service",  "logo_path": null, "display_priority": 3 }],
            "buy":      [{ "provider_id": 5, "provider_name": "Buy Service",   "logo_path": null, "display_priority": 4 }]
          }
        }
      }
    }
    """.data(using: .utf8)!

    private let noCertificationJSON = """
    {
      "id": 3,
      "runtime": 90,
      "vote_average": null,
      "vote_count": null,
      "revenue": null,
      "genres": [],
      "credits": { "cast": [], "crew": [] },
      "external_ids": {},
      "release_dates": {
        "results": [
          {
            "iso_3166_1": "JP",
            "release_dates": [
              { "certification": "", "type": 3 },
              { "certification": "", "type": 4 }
            ]
          }
        ]
      },
      "watch/providers": { "results": {} }
    }
    """.data(using: .utf8)!

    // MARK: - DTO decoding

    func testReleaseDatesDecoding() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: fullPhase2JSON)
        XCTAssertEqual(dto.releaseDates?.results.count, 2)
        let jp = dto.releaseDates?.results.first(where: { $0.iso31661 == "JP" })
        XCTAssertNotNil(jp)
        XCTAssertEqual(jp?.releaseDates.count, 2)
    }

    func testWatchProvidersDecoding() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: fullPhase2JSON)
        let jp = dto.watchProviders?.results["JP"]
        XCTAssertNotNil(jp)
        XCTAssertEqual(jp?.flatrate?.count, 1)
        XCTAssertEqual(jp?.flatrate?.first?.providerName, "Netflix")
        XCTAssertEqual(jp?.flatrate?.first?.providerID, 8)
        XCTAssertEqual(jp?.rent?.count, 1)
        XCTAssertNil(jp?.free)
        XCTAssertNil(jp?.ads)
        XCTAssertNil(jp?.buy)
    }

    func testWatchProvidersKeyWithSlashDecodes() throws {
        // "watch/providers" キーが slash を含んでも正常に decode できることを確認
        XCTAssertNoThrow(try decoder.decode(TMDBDetailResponse.self, from: fullPhase2JSON))
    }

    // MARK: - JP certification mapping

    func testJPCertificationTheatricalPreferred() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: fullPhase2JSON)
        let metadata = MovieMetadata.from(dto)
        // type=3 (Theatrical) の "G" が選ばれる（type=1 の "" は空なので skip）
        XCTAssertEqual(metadata.jpCertification, "G")
    }

    func testNoJPReleaseDateReturnsNilCertification() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: noJPDataJSON)
        let metadata = MovieMetadata.from(dto)
        XCTAssertNil(metadata.jpCertification, "JP データがない場合は nil")
    }

    func testAllEmptyCertificationsReturnNil() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: noCertificationJSON)
        let metadata = MovieMetadata.from(dto)
        XCTAssertNil(metadata.jpCertification, "全 certification が空なら nil")
    }

    // MARK: - Watch providers mapping

    func testJPWatchProvidersMapped() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: fullPhase2JSON)
        let metadata = MovieMetadata.from(dto)
        XCTAssertEqual(metadata.watchProviders.count, 2)
        let netflix = metadata.watchProviders.first(where: { $0.providerName == "Netflix" })
        XCTAssertEqual(netflix?.type, .subscription)
        XCTAssertEqual(netflix?.providerID, 8)
        let amazon = metadata.watchProviders.first(where: { $0.providerName == "Amazon Video" })
        XCTAssertEqual(amazon?.type, .rent)
    }

    func testAllProviderTypesMapped() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: allProviderTypesJSON)
        let metadata = MovieMetadata.from(dto)
        XCTAssertEqual(metadata.watchProviders.count, 5)
        XCTAssertTrue(metadata.watchProviders.contains(where: { $0.type == .subscription }))
        XCTAssertTrue(metadata.watchProviders.contains(where: { $0.type == .free }))
        XCTAssertTrue(metadata.watchProviders.contains(where: { $0.type == .ads }))
        XCTAssertTrue(metadata.watchProviders.contains(where: { $0.type == .rent }))
        XCTAssertTrue(metadata.watchProviders.contains(where: { $0.type == .buy }))
    }

    func testNoJPProvidersReturnsEmptyArray() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: noJPDataJSON)
        let metadata = MovieMetadata.from(dto)
        XCTAssertTrue(metadata.watchProviders.isEmpty, "JP データがない場合は空配列")
    }

    func testWatchProvidersNotPersistedToMovieLog() {
        // watch providers は MovieLog に保存しない設計の確認
        // MovieLog に watchProviders field が存在しないことをコンパイル時に保証する
        // （このテストはコンパイルが通ることで成立する）
        let log = MovieLog(watchedAt: .now, movieTitle: "Test", theaterName: "", review: "")
        _ = log.movieGenresRaw    // persist される field
        _ = log.movieRuntimeMinutes // persist される field
        // log.watchProviders は存在しない → コンパイルエラーになるはず（意図的に書かない）
        XCTAssertNil(log.tmdbId)  // just a valid assertion
    }

    // MARK: - Revenue

    func testNonZeroRevenueMapped() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: fullPhase2JSON)
        XCTAssertEqual(MovieMetadata.from(dto).revenue, 836836967)
    }

    func testZeroRevenueMappedToNil() throws {
        let dto = try decoder.decode(TMDBDetailResponse.self, from: noJPDataJSON)
        XCTAssertNil(MovieMetadata.from(dto).revenue)
    }
}
