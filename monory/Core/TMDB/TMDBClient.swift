import Foundation

enum TMDBClient {
    private static let baseURL = "https://api.themoviedb.org/3"
    static let imageBaseURL = "https://image.tmdb.org/t/p/w500"

    static func search(query: String) async throws -> [TMDBMovie] {
        let key = Secrets.tmdbAPIKey
        guard !key.isEmpty, key != "YOUR_TMDB_API_KEY" else {
            print("[TMDB] ⚠️ API key not set")
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
        print("[TMDB] 🔍 query=\(query)")
        do {
            let (data, response) = try await URLSession.shared.data(from: components.url!)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
            print("[TMDB] status=\(status) body=\(body)")
            let results = try JSONDecoder().decode(TMDBSearchResponse.self, from: data).results
            print("[TMDB] ✅ \(results.count) results")
            return results
        } catch {
            print("[TMDB] ❌ error=\(error)")
            throw error
        }
    }

    static func fetchPosterData(path: String) async throws -> Data {
        let url = URL(string: "\(imageBaseURL)\(path)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}
