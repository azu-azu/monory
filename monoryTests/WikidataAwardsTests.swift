/// Phase 3: Wikidata SPARQL response の decoding と award mapping を検証する。
import XCTest
@testable import monory

final class WikidataAwardsTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - Fixtures

    /// P1027 (conferred by) は除去済みのため、binding に含まれていても無視される
    private let fullResponseJSON = """
    {
      "results": {
        "bindings": [
          {
            "awardLabel": { "type": "literal", "value": "Academy Award for Best Visual Effects" },
            "year":        { "type": "literal", "value": "2011" },
            "type":        { "type": "literal", "value": "won" }
          },
          {
            "awardLabel": { "type": "literal", "value": "Academy Award for Best Picture" },
            "year":        { "type": "literal", "value": "2011" },
            "type":        { "type": "literal", "value": "nominated" }
          },
          {
            "awardLabel": { "type": "literal", "value": "Hugo Award for Best Dramatic Presentation" },
            "type":       { "type": "literal", "value": "won" }
          }
        ]
      }
    }
    """.data(using: .utf8)!

    private let emptyResponseJSON = """
    { "results": { "bindings": [] } }
    """.data(using: .utf8)!

    private let unknownTypeJSON = """
    {
      "results": {
        "bindings": [
          {
            "awardLabel": { "type": "literal", "value": "Some Award" },
            "type":       { "type": "literal", "value": "unknown_type" }
          }
        ]
      }
    }
    """.data(using: .utf8)!

    // MARK: - SPARQL DTO decoding

    func testFullResponseDecoding() throws {
        let response = try decoder.decode(WikidataSPARQLResponse.self, from: fullResponseJSON)
        XCTAssertEqual(response.results.bindings.count, 3)
    }

    func testWonAwardFieldsDecoded() throws {
        let response = try decoder.decode(WikidataSPARQLResponse.self, from: fullResponseJSON)
        let b = response.results.bindings[0]
        XCTAssertEqual(b.awardLabel?.value, "Academy Award for Best Visual Effects")
        XCTAssertEqual(b.year?.value, "2011")
        XCTAssertEqual(b.type?.value, "won")
    }

    func testNominatedAwardDecoded() throws {
        let response = try decoder.decode(WikidataSPARQLResponse.self, from: fullResponseJSON)
        let b = response.results.bindings[1]
        XCTAssertEqual(b.awardLabel?.value, "Academy Award for Best Picture")
        XCTAssertEqual(b.type?.value, "nominated")
        XCTAssertEqual(b.year?.value, "2011")
    }

    func testAwardWithNoYearDecoded() throws {
        let response = try decoder.decode(WikidataSPARQLResponse.self, from: fullResponseJSON)
        XCTAssertNil(response.results.bindings[2].year)
    }

    func testEmptyBindingsDecodes() throws {
        let response = try decoder.decode(WikidataSPARQLResponse.self, from: emptyResponseJSON)
        XCTAssertTrue(response.results.bindings.isEmpty)
    }

    // MARK: - Award mapping

    func testMapAwardsFullResponse() throws {
        let response = try decoder.decode(WikidataSPARQLResponse.self, from: fullResponseJSON)
        let awards = WikidataClient.mapAwards(from: response.results.bindings)
        XCTAssertEqual(awards.count, 3)
    }

    func testMapWonAward() throws {
        let response = try decoder.decode(WikidataSPARQLResponse.self, from: fullResponseJSON)
        let awards = WikidataClient.mapAwards(from: response.results.bindings)
        let vfx = awards.first(where: { $0.awardName.contains("Visual Effects") })
        XCTAssertNotNil(vfx)
        XCTAssertEqual(vfx?.type, .won)
        XCTAssertEqual(vfx?.year, 2011)
    }

    func testMapNominatedAward() throws {
        let response = try decoder.decode(WikidataSPARQLResponse.self, from: fullResponseJSON)
        let awards = WikidataClient.mapAwards(from: response.results.bindings)
        let bp = awards.first(where: { $0.awardName.contains("Best Picture") })
        XCTAssertEqual(bp?.type, .nominated)
        XCTAssertEqual(bp?.year, 2011)
    }

    func testMapAwardWithNoYear() throws {
        let response = try decoder.decode(WikidataSPARQLResponse.self, from: fullResponseJSON)
        let awards = WikidataClient.mapAwards(from: response.results.bindings)
        let hugo = awards.first(where: { $0.awardName.contains("Hugo") })
        XCTAssertNil(hugo?.year)
        XCTAssertEqual(hugo?.type, .won)
    }

    func testMapEmptyBindingsReturnsEmpty() throws {
        let response = try decoder.decode(WikidataSPARQLResponse.self, from: emptyResponseJSON)
        XCTAssertTrue(WikidataClient.mapAwards(from: response.results.bindings).isEmpty)
    }

    func testUnknownTypeIsFiltered() throws {
        // unknown_type は WikidataAward.AwardType に存在しない → compactMap でフィルタされる
        let response = try decoder.decode(WikidataSPARQLResponse.self, from: unknownTypeJSON)
        XCTAssertTrue(WikidataClient.mapAwards(from: response.results.bindings).isEmpty)
    }

    // MARK: - parseAwards convenience

    func testParseAwardsFromData() throws {
        let awards = try WikidataClient.parseAwards(from: fullResponseJSON)
        XCTAssertEqual(awards.count, 3)
    }

    func testParseAwardsFromEmptyData() throws {
        let awards = try WikidataClient.parseAwards(from: emptyResponseJSON)
        XCTAssertTrue(awards.isEmpty)
    }

    // MARK: - WikidataAward.id stability

    func testAwardIDIsStable() {
        let a1 = WikidataAward(awardName: "Oscar", year: 2011, type: .won)
        let a2 = WikidataAward(awardName: "Oscar", year: 2011, type: .won)
        XCTAssertEqual(a1.id, a2.id)
    }

    func testAwardIDDiffersOnType() {
        let won = WikidataAward(awardName: "Oscar", year: 2011, type: .won)
        let nom = WikidataAward(awardName: "Oscar", year: 2011, type: .nominated)
        XCTAssertNotEqual(won.id, nom.id)
    }

    func testAwardIDDiffersOnYear() {
        let a2011 = WikidataAward(awardName: "Oscar", year: 2011, type: .won)
        let a2012 = WikidataAward(awardName: "Oscar", year: 2012, type: .won)
        XCTAssertNotEqual(a2011.id, a2012.id)
    }
}
