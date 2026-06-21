import Foundation

struct TMDBSearchResponse: Decodable {
    let results: [TMDBMovie]
}

struct TMDBMovie: Decodable, Identifiable {
    let id: Int
    let title: String
    let originalTitle: String
    let overview: String
    let releaseDate: String?
    let posterPath: String?

    var releaseYear: Int? {
        guard let date = releaseDate, date.count >= 4 else { return nil }
        return Int(date.prefix(4))
    }

    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case originalTitle = "original_title"
        case releaseDate = "release_date"
        case posterPath = "poster_path"
    }
}

// MARK: - Detail response DTOs

struct TMDBDetailResponse: Decodable {
    let id: Int
    let runtime: Int?
    let voteAverage: Double?
    let voteCount: Int?
    let revenue: Int?
    let genres: [TMDBGenreDTO]
    let credits: TMDBCreditsDTO
    let externalIDs: TMDBExternalIDsDTO
    let releaseDates: TMDBReleaseDatesDTO?

    enum CodingKeys: String, CodingKey {
        case id, runtime, revenue, genres, credits
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case externalIDs = "external_ids"
        case releaseDates = "release_dates"
    }
}

struct TMDBGenreDTO: Decodable {
    let id: Int
    let name: String
}

struct TMDBCreditsDTO: Decodable {
    let cast: [TMDBCastMemberDTO]
    let crew: [TMDBCrewMemberDTO]
}

struct TMDBCastMemberDTO: Decodable {
    let name: String
    let order: Int
}

struct TMDBCrewMemberDTO: Decodable {
    let name: String
    let job: String
}

struct TMDBExternalIDsDTO: Decodable {
    let wikidataID: String?

    enum CodingKeys: String, CodingKey {
        case wikidataID = "wikidata_id"
    }
}

// MARK: - Release dates DTO (JP certification)

struct TMDBReleaseDatesDTO: Decodable {
    let results: [TMDBReleaseDateCountry]
}

struct TMDBReleaseDateCountry: Decodable {
    let iso31661: String
    let releaseDates: [TMDBReleaseDate]

    enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case releaseDates = "release_dates"
    }
}

struct TMDBReleaseDate: Decodable {
    let certification: String
    /// 1=Premiere 2=Limited 3=Theatrical 4=Digital 5=Physical 6=TV
    let type: Int
}

