/// Phase 1: TMDBDetailResponse → MovieMetadata の mapping ロジックを検証する。
/// cast slicing、director 抽出、revenue 0 → nil、partial response 耐性を確認する。
import XCTest
@testable import monory

final class MovieMetadataMappingTests: XCTestCase {

    // MARK: - Helpers

    private func makeDTO(
        id: Int = 1,
        runtime: Int? = 120,
        voteAverage: Double? = 7.5,
        voteCount: Int? = 1000,
        revenue: Int? = 5000000,
        genres: [TMDBGenreDTO] = [],
        cast: [TMDBCastMemberDTO] = [],
        crew: [TMDBCrewMemberDTO] = [],
        wikidataID: String? = nil
    ) -> TMDBDetailResponse {
        TMDBDetailResponse(
            id: id,
            runtime: runtime,
            voteAverage: voteAverage,
            voteCount: voteCount,
            revenue: revenue,
            genres: genres,
            credits: TMDBCreditsDTO(cast: cast, crew: crew),
            externalIDs: TMDBExternalIDsDTO(wikidataID: wikidataID),
            releaseDates: nil,
            watchProviders: nil
        )
    }

    private func castMembers(_ names: [String]) -> [TMDBCastMemberDTO] {
        names.enumerated().map { TMDBCastMemberDTO(name: $0.element, order: $0.offset) }
    }

    private func crewMember(name: String, job: String) -> TMDBCrewMemberDTO {
        TMDBCrewMemberDTO(name: name, job: job)
    }

    // MARK: - Basic mapping

    func testVoteAverageAndCountMapped() {
        let dto = makeDTO(voteAverage: 8.365, voteCount: 36483)
        let metadata = MovieMetadata.from(dto)
        XCTAssertEqual(metadata.voteAverage ?? 0, 8.365, accuracy: 0.001)
        XCTAssertEqual(metadata.voteCount, 36483)
    }

    func testRuntimeMapped() {
        let metadata = MovieMetadata.from(makeDTO(runtime: 148))
        XCTAssertEqual(metadata.runtimeMinutes, 148)
    }

    func testNilRuntimePassedThrough() {
        let metadata = MovieMetadata.from(makeDTO(runtime: nil))
        XCTAssertNil(metadata.runtimeMinutes)
    }

    func testGenreNamesMapped() {
        let dto = makeDTO(genres: [
            TMDBGenreDTO(id: 28, name: "Action"),
            TMDBGenreDTO(id: 878, name: "Science Fiction")
        ])
        let metadata = MovieMetadata.from(dto)
        XCTAssertEqual(metadata.genres, ["Action", "Science Fiction"])
    }

    func testEmptyGenresResultsInEmptyArray() {
        let metadata = MovieMetadata.from(makeDTO(genres: []))
        XCTAssertTrue(metadata.genres.isEmpty)
    }

    // MARK: - Director extraction

    func testDirectorExtracted() {
        let dto = makeDTO(crew: [
            crewMember(name: "Christopher Nolan", job: "Director"),
            crewMember(name: "Emma Thomas", job: "Producer")
        ])
        XCTAssertEqual(MovieMetadata.from(dto).director, "Christopher Nolan")
    }

    func testNoDirectorInCrewReturnsNil() {
        let dto = makeDTO(crew: [crewMember(name: "Emma Thomas", job: "Producer")])
        XCTAssertNil(MovieMetadata.from(dto).director)
    }

    func testEmptyCrewReturnsNilDirector() {
        XCTAssertNil(MovieMetadata.from(makeDTO(crew: [])).director)
    }

    func testMultipleDirectorsFirstIsUsed() {
        let dto = makeDTO(crew: [
            crewMember(name: "Director A", job: "Director"),
            crewMember(name: "Director B", job: "Director")
        ])
        XCTAssertEqual(MovieMetadata.from(dto).director, "Director A")
    }

    // MARK: - Cast slicing (上位 5 人)

    func testZeroCastReturnsEmptyArray() {
        XCTAssertTrue(MovieMetadata.from(makeDTO(cast: [])).topCast.isEmpty)
    }

    func testOneCastMember() {
        let dto = makeDTO(cast: castMembers(["Actor A"]))
        XCTAssertEqual(MovieMetadata.from(dto).topCast, ["Actor A"])
    }

    func testExactlyFiveCastMembers() {
        let names = ["A", "B", "C", "D", "E"]
        let dto = makeDTO(cast: castMembers(names))
        XCTAssertEqual(MovieMetadata.from(dto).topCast, names)
    }

    func testMoreThanFiveCastMembersSlicedToTop5() {
        let names = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
        let dto = makeDTO(cast: castMembers(names))
        let metadata = MovieMetadata.from(dto)
        XCTAssertEqual(metadata.topCast.count, 5)
        XCTAssertEqual(metadata.topCast, Array(names.prefix(5)))
    }

    func testCastSortedByOrderBeforeSlicing() {
        // order が逆順で来ても billing order 通りに並ぶ
        let dto = makeDTO(cast: [
            TMDBCastMemberDTO(name: "Third", order: 2),
            TMDBCastMemberDTO(name: "First",  order: 0),
            TMDBCastMemberDTO(name: "Second", order: 1),
            TMDBCastMemberDTO(name: "Sixth",  order: 5),
            TMDBCastMemberDTO(name: "Fourth", order: 3),
            TMDBCastMemberDTO(name: "Fifth",  order: 4)
        ])
        let top5 = MovieMetadata.from(dto).topCast
        XCTAssertEqual(top5, ["First", "Second", "Third", "Fourth", "Fifth"])
    }

    // MARK: - Revenue: 0 → nil

    func testZeroRevenueMappedToNil() {
        XCTAssertNil(MovieMetadata.from(makeDTO(revenue: 0)).revenue)
    }

    func testNilRevenueMappedToNil() {
        XCTAssertNil(MovieMetadata.from(makeDTO(revenue: nil)).revenue)
    }

    func testNonZeroRevenueMapped() {
        XCTAssertEqual(MovieMetadata.from(makeDTO(revenue: 836836967)).revenue, 836836967)
    }

    // MARK: - WikidataID passthrough

    func testWikidataIDMapped() {
        let dto = makeDTO(wikidataID: "Q25188")
        XCTAssertEqual(MovieMetadata.from(dto).wikidataID, "Q25188")
    }

    func testNilWikidataIDMapped() {
        XCTAssertNil(MovieMetadata.from(makeDTO(wikidataID: nil)).wikidataID)
    }

    // MARK: - Phase 2 fields are empty stubs in Phase 1

    func testWatchProvidersEmptyInPhase1() {
        XCTAssertTrue(MovieMetadata.from(makeDTO()).watchProviders.isEmpty)
    }

    func testJPCertificationNilInPhase1() {
        XCTAssertNil(MovieMetadata.from(makeDTO()).jpCertification)
    }

    // MARK: - Raw string encoding for MovieLog persistence

    func testGenresJoinedWithComma() {
        let dto = makeDTO(genres: [
            TMDBGenreDTO(id: 28, name: "Action"),
            TMDBGenreDTO(id: 18, name: "Drama")
        ])
        let metadata = MovieMetadata.from(dto)
        let raw = metadata.genres.joined(separator: ",")
        XCTAssertEqual(raw, "Action,Drama")
        XCTAssertEqual(raw.split(separator: ",").map(String.init), ["Action", "Drama"])
    }

    func testCastJoinedWithComma() {
        let dto = makeDTO(cast: castMembers(["DiCaprio", "Nolan", "Hardy"]))
        let metadata = MovieMetadata.from(dto)
        let raw = metadata.topCast.joined(separator: ",")
        XCTAssertEqual(raw, "DiCaprio,Nolan,Hardy")
    }

    func testEmptyGenresProduceNilRaw() {
        let metadata = MovieMetadata.from(makeDTO(genres: []))
        let raw: String? = metadata.genres.isEmpty ? nil : metadata.genres.joined(separator: ",")
        XCTAssertNil(raw)
    }
}
