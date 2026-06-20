import Foundation

struct WikidataClient {
    private static let sparqlEndpoint = URL(string: "https://query.wikidata.org/sparql")!
    private static let userAgent = "monory/1.0 (iOS; personal non-commercial use)"
    private static let decoder = JSONDecoder()

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    // MARK: - Public API

    static func fetchAwards(wikidataID: String) async throws -> [WikidataAward] {
        var components = URLComponents(url: sparqlEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "query", value: sparqlQuery(for: wikidataID)),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url else { throw WikidataError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/sparql-results+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            throw WikidataError.rateLimited
        }
        return try parseAwards(from: data)
    }

    // MARK: - Parsing (internal for testability)

    static func parseAwards(from data: Data) throws -> [WikidataAward] {
        let response = try decoder.decode(WikidataSPARQLResponse.self, from: data)
        return mapAwards(from: response.results.bindings)
    }

    static func mapAwards(from bindings: [WikidataSPARQLResponse.Binding]) -> [WikidataAward] {
        bindings.compactMap { binding in
            guard
                let awardName = binding.awardLabel?.value,
                let typeString = binding.type?.value,
                let awardType = WikidataAward.AwardType(rawValue: typeString)
            else { return nil }
            return WikidataAward(
                awardName: awardName,
                categoryName: binding.categoryLabel?.value,
                year: binding.year.flatMap { Int($0.value) },
                type: awardType
            )
        }
    }

    // MARK: - SPARQL query

    private static func sparqlQuery(for wikidataID: String) -> String {
        // Sanitize: Wikidata ID は Q + 数字のみ
        let safe = wikidataID.filter { $0 == "Q" || $0.isNumber }
        return """
        SELECT ?awardLabel ?categoryLabel ?year ?type WHERE {
          VALUES ?entity { wd:\(safe) }
          {
            ?entity p:P166 ?stmt.
            BIND("won" AS ?type)
            ?stmt ps:P166 ?award.
            OPTIONAL { ?stmt pq:P585 ?date. BIND(YEAR(?date) AS ?year) }
            OPTIONAL { ?stmt pq:P1027 ?category. }
          } UNION {
            ?entity p:P1411 ?stmt.
            BIND("nominated" AS ?type)
            ?stmt ps:P1411 ?award.
            OPTIONAL { ?stmt pq:P585 ?date. BIND(YEAR(?date) AS ?year) }
            OPTIONAL { ?stmt pq:P1027 ?category. }
          }
          SERVICE wikibase:label { bd:serviceParam wikibase:language "ja,en". }
        }
        LIMIT 100
        """
    }
}
