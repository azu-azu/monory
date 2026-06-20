import Foundation
import OSLog

enum TMDBClient {
    private static let baseURL = "https://api.themoviedb.org/3"
    static let imageBaseURL = "https://image.tmdb.org/t/p/w500"
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "monory", category: "TMDB")

    static func search(query: String) async throws -> [TMDBMovie] {
        let key = Secrets.tmdbAPIKey
        guard !key.isEmpty, key != "YOUR_TMDB_API_KEY" else {
            logger.warning("API key not set")
            return []
        }

        var components = URLComponents(string: "\(baseURL)/search/movie")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: key),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "language", value: "ja-JP"),
            URLQueryItem(name: "region", value: "JP"),
            URLQueryItem(name: "page", value: "1"),
        ]
        logger.debug("query=\(query, privacy: .private)")
        do {
            let (data, response) = try await URLSession.shared.data(from: components.url!)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let results = try JSONDecoder().decode(TMDBSearchResponse.self, from: data).results
            logger.debug("status=\(status) results=\(results.count)")
            return results
        } catch {
            logger.error("search failed: \(error)")
            throw error
        }
    }

    static func fetchPosterData(path: String) async throws -> Data {
        let url = URL(string: "\(imageBaseURL)\(path)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}
