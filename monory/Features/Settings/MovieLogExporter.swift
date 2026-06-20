import Foundation

struct MovieLogExporter {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func export(logs: [MovieLog]) -> Data {
        let header = [
            "タイトル", "原題", "公開年", "観た日", "評価",
            "種別", "映画館名", "配信サービス", "上映形式",
            "スクリーン", "座席", "追加視聴日", "感想", "TMDB ID",
            "映画館メモ", "文化的インパクト", "参考URL",
        ]

        var rows: [[String]] = [header]

        for log in logs {
            let watchedAt: String
            if log.watchedAtUnknown {
                watchedAt = "不明"
            } else if log.watchedYearOnly {
                watchedAt = String(Calendar.current.component(.year, from: log.watchedAt))
            } else {
                watchedAt = dateFormatter.string(from: log.watchedAt)
            }

            let sortedDates = log.viewingDates
                .sorted { $0.date < $1.date }
                .map { dateFormatter.string(from: $0.date) }
                .joined(separator: "/")

            let sourceURLs = log.culturalImpactSources
                .map(\.absoluteString)
                .joined(separator: "|")

            let row: [String] = [
                log.movieTitle,
                log.movieOriginalTitle ?? "",
                log.movieReleaseYear.map { String($0) } ?? "",
                watchedAt,
                log.rating.map { String($0) } ?? "",
                log.viewingType,
                log.theaterName,
                log.streamingService ?? "",
                log.screeningFormat,
                log.screenNumber ?? "",
                log.seatNumber ?? "",
                sortedDates,
                log.review,
                log.tmdbId.map { String($0) } ?? "",
                log.theaterMemo,
                log.culturalImpactNote,
                sourceURLs,
            ]
            rows.append(row)
        }

        let csv = rows
            .map { $0.map(escapeField).joined(separator: ",") }
            .joined(separator: "\r\n")

        // UTF-8 BOM + CSV
        let bom = Data([0xEF, 0xBB, 0xBF])
        return bom + (csv.data(using: .utf8) ?? Data())
    }

    static func fileName() -> String {
        "monory_export_\(dateFormatter.string(from: Date())).csv"
    }

    private static func escapeField(_ value: String) -> String {
        // RFC 4180: フィールドに , " \r \n が含まれる場合は " で囲み、" は "" にエスケープ
        guard value.contains(",") || value.contains("\"")
                || value.contains("\r") || value.contains("\n") else {
            return value
        }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
