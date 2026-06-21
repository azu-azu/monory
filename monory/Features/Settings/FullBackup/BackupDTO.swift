import Foundation

// MARK: - Manifest

struct BackupManifest: Codable, Sendable {
    let formatVersion: Int
    let exportedAt: Date
    let appVersion: String
}

// MARK: - DTOs

struct MovieLogDTO: Codable, Sendable {
    let id: String
    let watchedAt: Date
    let movieTitle: String
    let theaterName: String
    let review: String
    let screenNumber: String?
    let seatNumber: String?
    let screeningFormat: String
    let admissionFee: Int?
    let viewingType: String
    let streamingService: String?
    let tmdbId: Int?
    let movieOriginalTitle: String?
    let movieReleaseYear: Int?
    let movieSynopsis: String?
    let posterImageExt: String?
    let watchedAtUnknown: Bool
    let watchedYearOnly: Bool
    let theaterMemo: String
    let rating: Int?
    let createdAt: Date
    let updatedAt: Date
    let ticketImages: [TicketImageDTO]
    let viewingDates: [ViewingDateDTO]
    // Phase 1 extended metadata — optional for backward compatibility with old backups
    let movieRuntimeMinutes: Int?
    let movieGenresRaw: String?
    let movieDirector: String?
    let movieCastRaw: String?
    let metadataUpdatedAt: Date?
}

struct TicketImageDTO: Codable, Sendable {
    let id: String
    let createdAt: Date
    let ocrRawText: String?
    let imageExt: String
}

struct ViewingDateDTO: Codable, Sendable {
    let id: String
    let date: Date
}

struct SettingsDTO: Codable, Sendable {
    let streamingServiceOrder: [String]
}

// MARK: - Payload（Task.detached boundary を越える中間型）

struct BackupPayload: Sendable {
    let manifest: BackupManifest
    let logs: [MovieLogDTO]
    let settings: SettingsDTO
    /// key: "<uuid>.<ext>", value: image Data
    let imageData: [String: Data]
}

// MARK: - Snapshot（export 用の MainActor → detached 受け渡し型）

struct BackupSnapshot: Sendable {
    struct LogEntry: Sendable {
        let dto: MovieLogDTO
        let posterData: Data?
        let tickets: [(filename: String, data: Data)]
    }

    let logs: [LogEntry]
    let settings: SettingsDTO
}

// MARK: - ImportMode / ImportResult

enum ImportMode: Sendable {
    case replace
    case merge
}

struct ImportResult: Sendable {
    let restoredCount: Int
    let updatedCount: Int
    let skippedCount: Int

    var summary: String {
        var parts: [String] = []
        if restoredCount > 0 { parts.append("\(restoredCount)件を復元") }
        if updatedCount > 0  { parts.append("\(updatedCount)件を更新") }
        if skippedCount > 0  { parts.append("\(skippedCount)件をスキップ（ローカルが新しい）") }
        return parts.isEmpty ? "変更なし" : parts.joined(separator: "、") + "しました"
    }
}

// MARK: - BackupError

enum BackupError: LocalizedError, Sendable {
    case unsupportedVersion(Int)
    case missingRequiredFile(String)
    case invalidArchive
    case resourceLimitExceeded

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v):
            return "未対応のバックアップ形式です（version \(v)）"
        case .missingRequiredFile(let name):
            return "バックアップファイルが壊れています（\(name) が見つかりません）"
        case .invalidArchive:
            return "バックアップファイルを開けませんでした"
        case .resourceLimitExceeded:
            return "バックアップファイルが大きすぎます"
        }
    }
}
