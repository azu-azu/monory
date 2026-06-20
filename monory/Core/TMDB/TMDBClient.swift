import Foundation
import OSLog

enum TMDBError: Error {
    case missingAPIKey
}

enum TMDBClient {
    private static let baseURL = "https://api.themoviedb.org/3"
    static let imageBaseURL = "https://image.tmdb.org/t/p/w500"
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "monory", category: "TMDB")
    private static let decoder = JSONDecoder()

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

    static func fetchMovieDetails(id: Int) async throws -> MovieMetadata {
        let key = Secrets.tmdbAPIKey
        guard !key.isEmpty, key != "YOUR_TMDB_API_KEY" else {
            logger.warning("API key not set")
            throw TMDBError.missingAPIKey
        }

        var components = URLComponents(string: "\(baseURL)/movie/\(id)")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: key),
            URLQueryItem(name: "language", value: "ja-JP"),
            URLQueryItem(name: "append_to_response", value: "credits,release_dates,watch/providers,external_ids"),
        ]
        logger.debug("fetchMovieDetails id=\(id)")
        do {
            let (data, response) = try await URLSession.shared.data(from: components.url!)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.debug("fetchMovieDetails status=\(status)")
            let dto = try decoder.decode(TMDBDetailResponse.self, from: data)
            return MovieMetadata.from(dto)
        } catch {
            logger.error("fetchMovieDetails failed: \(error)")
            throw error
        }
    }
}
