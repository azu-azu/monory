/// Phase 0 spike: comma-joined raw String と JSON Data の encoding/decoding を比較する。
/// TMDB genre / person name の comma collision リスクと、URL の comma を正しく扱えるかを検証する。
import XCTest

final class RawCollectionEncodingTests: XCTestCase {

    // MARK: - Comma-joined encoding

    func testCommaJoinedRoundTrip() {
        let genres = ["Action", "Drama", "Science Fiction"]
        let raw = genres.joined(separator: ",")
        let decoded = raw.split(separator: ",").map(String.init)
        XCTAssertEqual(decoded, genres)
    }

    func testCommaJoinedEmptyArray() {
        let raw = [String]().joined(separator: ",")
        let decoded: [String] = raw.isEmpty ? [] : raw.split(separator: ",").map(String.init)
        XCTAssertEqual(decoded, [])
    }

    /// comma-joined は値に comma が含まれると collision する。
    /// このテストは意図的に失敗を示す — TMDB person name が "LastName, FirstName" 形式なら要 JSON 切替。
    func testCommaDelimiterCollisionDetection() {
        let namesWithComma = ["LastName, FirstName", "Drama"]
        let raw = namesWithComma.joined(separator: ",")
        let decoded = raw.split(separator: ",").map(String.init)
        // collision が起きると decoded は 3 要素になる
        XCTAssertNotEqual(decoded, namesWithComma,
            "Comma delimiter collision: TMDB person name に comma が含まれる場合 JSON encoding へ切替が必要")
        XCTAssertEqual(decoded.count, 3, "comma を含む要素が split で分割されている")
    }

    /// TMDB の genre label に comma が含まれないことを実データで確認する。
    func testTMDBKnownGenresAreCommaFree() {
        let tmdbGenres = [
            "Action", "Adventure", "Animation", "Comedy", "Crime",
            "Documentary", "Drama", "Family", "Fantasy", "History",
            "Horror", "Music", "Mystery", "Romance", "Science Fiction",
            "TV Movie", "Thriller", "War", "Western"
        ]
        for genre in tmdbGenres {
            XCTAssertFalse(genre.contains(","), "Genre '\(genre)' に comma が含まれる — JSON encoding へ切替が必要")
        }
    }

    // MARK: - JSON Data encoding

    func testJSONDataRoundTrip() throws {
        let values = ["Action", "Drama", "Science Fiction"]
        let data = try JSONEncoder().encode(values)
        let decoded = try JSONDecoder().decode([String].self, from: data)
        XCTAssertEqual(decoded, values)
    }

    /// JSON encoding は comma を含む値でも collision しない。
    func testJSONDataHandlesCommasInValues() throws {
        let values = ["LastName, FirstName", "Co-Director, Assistant"]
        let data = try JSONEncoder().encode(values)
        let decoded = try JSONDecoder().decode([String].self, from: data)
        XCTAssertEqual(decoded, values)
    }

    func testJSONDataEmptyArray() throws {
        let data = try JSONEncoder().encode([String]())
        let decoded = try JSONDecoder().decode([String].self, from: data)
        XCTAssertEqual(decoded, [])
    }

    // MARK: - URL JSON encoding (culturalImpactSourcesData)

    /// URL は comma を raw で含める（RFC 3986 sub-delimiter）。
    /// comma-joined では collision するため JSON Data で保持する。
    func testURLsWithCommasRoundTrip() throws {
        let urls = ["https://example.com/path?list=a,b,c", "https://other.com/page"]
        let data = try JSONEncoder().encode(urls)
        let decoded = try JSONDecoder().decode([String].self, from: data)
        XCTAssertEqual(decoded, urls)
    }

    func testInvalidURLsAreFilteredOnRead() throws {
        let raw = ["https://valid.com", "", "not a url", "https://also-valid.com"]
        let data = try JSONEncoder().encode(raw)
        let strings = try JSONDecoder().decode([String].self, from: data)
        let urls = strings.compactMap { URL(string: $0) }.filter { $0.scheme != nil }
        XCTAssertEqual(urls.map(\.absoluteString), ["https://valid.com", "https://also-valid.com"])
    }

    func testWhitespaceURLsAreFilteredOnRead() throws {
        let raw = ["https://valid.com", "   ", "\t", "https://other.com"]
        let data = try JSONEncoder().encode(raw)
        let strings = try JSONDecoder().decode([String].self, from: data)
        let urls = strings
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap { URL(string: $0) }
            .filter { $0.scheme != nil }
        XCTAssertEqual(urls.count, 2)
    }

    // MARK: - MovieGenres / MovieCast computed property behavior

    func testComputedPropertyNilReturnsEmpty() {
        let raw: String? = nil
        let result: [String] = {
            guard let r = raw, !r.isEmpty else { return [] }
            return r.split(separator: ",").map(String.init)
        }()
        XCTAssertEqual(result, [])
    }

    func testComputedPropertyEmptyStringReturnsEmpty() {
        let raw: String? = ""
        let result: [String] = {
            guard let r = raw, !r.isEmpty else { return [] }
            return r.split(separator: ",").map(String.init)
        }()
        XCTAssertEqual(result, [])
    }

    func testComputedPropertyNonEmptyReturnsArray() {
        let raw: String? = "Action,Drama,Science Fiction"
        let result: [String] = {
            guard let r = raw, !r.isEmpty else { return [] }
            return r.split(separator: ",").map(String.init)
        }()
        XCTAssertEqual(result, ["Action", "Drama", "Science Fiction"])
    }
}
