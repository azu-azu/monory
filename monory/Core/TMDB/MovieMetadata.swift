import Foundation

// MARK: - Watch providers (Phase 2)

struct WatchProvider: Hashable, Identifiable {
    let providerID: Int
    let providerName: String
    let logoPath: String?
    let displayPriority: Int
    let type: WatchProviderType

    var id: String { "\(type.rawValue):\(providerID)" }
}

enum WatchProviderType: String, CaseIterable {
    case subscription  // TMDB: flatrate
    case free
    case ads
    case rent
    case buy
}

// MARK: - Domain model

struct MovieMetadata {
    // Phase 1: live data — fetch fresh, do not persist
    let voteAverage: Double?
    let voteCount: Int?
    let revenue: Int?               // TMDB 0 → nil; Phase 2 display

    // Phase 1: persist to MovieLog
    let runtimeMinutes: Int?
    let genres: [String]
    let director: String?
    let topCast: [String]           // billing order 上位 5 人

    // Phase 2: live regional data
    let jpCertification: String?
    let watchProviders: [WatchProvider]

    // Phase 3: optional enrichment
    let wikidataID: String?
}

// MARK: - DTO mapping

extension MovieMetadata {
    static func from(_ dto: TMDBDetailResponse) -> MovieMetadata {
        let director = dto.credits.crew
            .first(where: { $0.job == "Director" })
            .map(\.name)

        let topCast = Array(
            dto.credits.cast
                .sorted(by: { $0.order < $1.order })
                .prefix(5)
                .map(\.name)
        )

        // TMDB は revenue 不明時に 0 を返す（null ではない）
        let revenue: Int? = (dto.revenue ?? 0) == 0 ? nil : dto.revenue

        let jpCertification = extractJPCertification(from: dto.releaseDates)
        let watchProviders = extractJPWatchProviders(from: dto.watchProviders)

        return MovieMetadata(
            voteAverage: dto.voteAverage,
            voteCount: dto.voteCount,
            revenue: revenue,
            runtimeMinutes: dto.runtime,
            genres: dto.genres.map(\.name),
            director: director,
            topCast: topCast,
            jpCertification: jpCertification,
            watchProviders: watchProviders,
            wikidataID: dto.externalIDs.wikidataID
        )
    }

    // MARK: - Private extraction helpers

    private static func extractJPCertification(from dto: TMDBReleaseDatesDTO?) -> String? {
        guard let jp = dto?.results.first(where: { $0.iso31661 == "JP" }) else { return nil }
        // Theatrical (type=3) を優先、なければ非空の最初の certification を使う
        let theatrical = jp.releaseDates.first(where: { $0.type == 3 && !$0.certification.isEmpty })
        let any = jp.releaseDates.first(where: { !$0.certification.isEmpty })
        return theatrical?.certification ?? any?.certification
    }

    private static func extractJPWatchProviders(from dto: TMDBWatchProvidersDTO?) -> [WatchProvider] {
        guard let jp = dto?.results["JP"] else { return [] }

        func map(_ providers: [TMDBProviderDTO]?, type: WatchProviderType) -> [WatchProvider] {
            (providers ?? []).map {
                WatchProvider(
                    providerID: $0.providerID,
                    providerName: $0.providerName,
                    logoPath: $0.logoPath,
                    displayPriority: $0.displayPriority,
                    type: type
                )
            }
        }

        return map(jp.flatrate, type: .subscription)
            + map(jp.free, type: .free)
            + map(jp.ads, type: .ads)
            + map(jp.rent, type: .rent)
            + map(jp.buy, type: .buy)
    }
}
