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
