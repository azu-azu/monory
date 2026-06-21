import SwiftData
import Foundation

@MainActor
@Observable
final class MovieMetadataViewModel {
    private(set) var metadata: MovieMetadata?
    private(set) var isLoading = false
    /// 初回 load 失敗時のエラー（live data セクションに表示）
    private(set) var loadError: Error?
    /// refresh 失敗時のエラー（non-blocking、既存データは維持）
    private(set) var refreshError: Error?
    /// Phase 3: Wikidata awards（session-only、persist しない）
    private(set) var awards: [WikidataAward] = []
    private(set) var awardsLoading = false
    private(set) var awardsError: Error?

    private let log: MovieLog
    private let context: ModelContext

    init(log: MovieLog, context: ModelContext) {
        self.log = log
        self.context = context
    }

    func load() async {
        guard let tmdbId = log.tmdbId, metadata == nil else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            metadata = try await TMDBClient.fetchMovieDetails(id: tmdbId)
        } catch {
            loadError = error
        }
    }

    func refresh() async {
        guard let tmdbId = log.tmdbId else { return }
        isLoading = true
        refreshError = nil
        defer { isLoading = false }
        do {
            let result = try await TMDBClient.fetchMovieDetails(id: tmdbId)
            metadata = result
            applyToLog(result)
            try? context.save()
        } catch {
            // 失敗時も既存 metadata は維持する
            refreshError = error
        }
        await loadAwards()
    }

    func loadAwards() async {
        guard let wikidataID = metadata?.wikidataID else { return }
        awardsLoading = true
        awardsError = nil
        defer { awardsLoading = false }
        do {
            awards = try await WikidataClient.fetchAwards(wikidataID: wikidataID)
        } catch {
            awardsError = error
            // non-fatal: 既存 awards は維持しない（empty のまま）
        }
    }

    private func applyToLog(_ m: MovieMetadata) {
        log.movieRuntimeMinutes = m.runtimeMinutes
        log.movieGenresRaw = m.genres.isEmpty ? nil : m.genres.joined(separator: ",")
        log.movieDirector = m.director
        log.movieCastRaw = m.topCast.isEmpty ? nil : m.topCast.joined(separator: ",")
        log.metadataUpdatedAt = Date()
    }

    // MARK: - Convenience accessors
    // Phase 1: live data があればそちら、なければ persisted 値にフォールバック
    var runtimeMinutes: Int? { metadata?.runtimeMinutes ?? log.movieRuntimeMinutes }
    var genres: [String]     { metadata?.genres         ?? log.movieGenres }
    var director: String?    { metadata?.director       ?? log.movieDirector }
    var cast: [String]       { metadata?.topCast        ?? log.movieCast }
    var voteAverage: Double? { metadata?.voteAverage }
    var voteCount: Int?      { metadata?.voteCount }

    // Phase 2: live regional data（persist しない）
    var jpCertification: String?   { metadata?.jpCertification }
    var revenue: Int?              { metadata?.revenue }


}
