import Foundation

// MARK: - Domain model

struct WikidataAward: Identifiable, Hashable {
    enum AwardType: String, Hashable {
        case won
        case nominated
    }

    let awardName: String
    let year: Int?
    let type: AwardType

    /// Stable ID: award type + year + name の組み合わせ（同一レコードが重複しない前提）
    var id: String { "\(type.rawValue):\(year.map(String.init) ?? ""):\(awardName)" }
}

// MARK: - Errors

enum WikidataError: LocalizedError {
    case rateLimited
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .rateLimited:    return "リクエスト過多です。しばらく待ってから再試行してください"
        case .invalidResponse: return "Wikidata からの応答が無効です"
        }
    }
}

// MARK: - SPARQL response DTOs

struct WikidataSPARQLResponse: Decodable {
    struct Results: Decodable {
        let bindings: [Binding]
    }

    struct Binding: Decodable {
        struct Value: Decodable {
            let value: String
        }
        let awardLabel: Value?
        let year: Value?
        let type: Value?
    }

    let results: Results
}
