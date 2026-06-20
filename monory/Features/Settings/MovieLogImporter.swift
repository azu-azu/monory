import Foundation
import SwiftData

struct MovieLogImporter {
    struct ImportResult {
        let importedCount: Int
        let skippedCount: Int
        let invalidDateCount: Int

        var importSummary: String {
            var parts: [String] = []
            if invalidDateCount > 0 { parts.append("\(invalidDateCount)件の日付を「不明」として処理") }
            if skippedCount > 0     { parts.append("\(skippedCount)件はスキップ") }
            let suffix = parts.isEmpty ? "" : "（\(parts.joined(separator: "、"))）"
            return "\(importedCount)件をインポートしました\(suffix)"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MovieLogExporter の列順と1対1で対応させる
    private enum Col: Int {
        case title = 0, originalTitle, releaseYear, watchedAt,
             rating, viewingType, theaterName, streamingService,
             screeningFormat, screenNumber, seatNumber,
             additionalDates, review, tmdbId,
             theaterMemo
        static let minCount = 14  // 旧フォーマット互換
        static let count = 15
    }

    static func `import`(data: Data, into context: ModelContext) -> ImportResult {
        // UTF-8 BOM を除去
        var csvData = data
        if csvData.prefix(3) == Data([0xEF, 0xBB, 0xBF]) {
            csvData = csvData.dropFirst(3)
        }
        guard let text = String(data: csvData, encoding: .utf8) else {
            return ImportResult(importedCount: 0, skippedCount: 0, invalidDateCount: 0)
        }

        var rows = parseCSV(text)
        guard rows.count > 1 else { return ImportResult(importedCount: 0, skippedCount: 0) }
        rows.removeFirst() // header row

        var imported = 0
        var skipped = 0
        var invalidDates = 0

        for row in rows {
            // 空行・列数不足はスキップ（末尾の空行も含む）
            guard row.count >= Col.minCount, !row[Col.title.rawValue].isEmpty else {
                if !row.allSatisfy({ $0.isEmpty }) { skipped += 1 }
                continue
            }

            let watchedAtStr = row[Col.watchedAt.rawValue]
            let isUnknown = watchedAtStr == "不明"
            let isYearOnly = !isUnknown && watchedAtStr.count == 4 && Int(watchedAtStr) != nil
            let parsedDate: Date? = (!isUnknown && !isYearOnly) ? dateFormatter.date(from: watchedAtStr) : nil
            let isInvalidDate = !isUnknown && !isYearOnly && parsedDate == nil

            let watchedAt: Date
            if isYearOnly, let year = Int(watchedAtStr) {
                watchedAt = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
            } else if let date = parsedDate {
                watchedAt = date
            } else {
                watchedAt = Date()  // 内部値。UI は watchedAtUnknown で「不明」と表示
            }

            let log = MovieLog(
                watchedAt: watchedAt,
                movieTitle: row[Col.title.rawValue],
                theaterName: row[Col.theaterName.rawValue],
                review: row[Col.review.rawValue]
            )
            log.movieOriginalTitle  = row[Col.originalTitle.rawValue].isEmpty ? nil : row[Col.originalTitle.rawValue]
            log.movieReleaseYear    = Int(row[Col.releaseYear.rawValue])
            log.watchedAtUnknown    = isUnknown || isInvalidDate
            log.watchedYearOnly     = isYearOnly
            if isInvalidDate { invalidDates += 1 }
            log.rating              = Int(row[Col.rating.rawValue])
            log.viewingType         = row[Col.viewingType.rawValue].isEmpty ? ViewingType.theater.rawValue : row[Col.viewingType.rawValue]
            log.streamingService    = row[Col.streamingService.rawValue].isEmpty ? nil : row[Col.streamingService.rawValue]
            log.screeningFormat     = row[Col.screeningFormat.rawValue].isEmpty ? ScreeningFormat.standard.rawValue : row[Col.screeningFormat.rawValue]
            log.screenNumber        = row[Col.screenNumber.rawValue].isEmpty ? nil : row[Col.screenNumber.rawValue]
            log.seatNumber          = row[Col.seatNumber.rawValue].isEmpty ? nil : row[Col.seatNumber.rawValue]
            log.tmdbId              = Int(row[Col.tmdbId.rawValue])
            log.theaterMemo         = row.count > Col.theaterMemo.rawValue ? row[Col.theaterMemo.rawValue] : ""

            context.insert(log)

            // 追加視聴日: "/" 区切りで複数日付
            if !row[Col.additionalDates.rawValue].isEmpty {
                for part in row[Col.additionalDates.rawValue].split(separator: "/", omittingEmptySubsequences: true) {
                    if let date = dateFormatter.date(from: String(part)) {
                        let vd = ViewingDate(date: date)
                        context.insert(vd)
                        log.viewingDates.append(vd)
                    } else {
                        invalidDates += 1
                    }
                }
            }

            imported += 1
        }

        return ImportResult(importedCount: imported, skippedCount: skipped, invalidDateCount: invalidDates)
    }

    // MARK: - RFC 4180 CSV parser

    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = text.startIndex

        while i < text.endIndex {
            let c = text[i]
            let next = text.index(after: i)

            if inQuotes {
                if c == "\"" {
                    if next < text.endIndex && text[next] == "\"" {
                        // "" → " (escaped quote)
                        current.append("\"")
                        i = text.index(after: next)
                        continue
                    }
                    inQuotes = false
                } else {
                    current.append(c)
                }
            } else {
                switch c {
                case "\"":
                    inQuotes = true
                case ",":
                    fields.append(current)
                    current = ""
                case "\r":
                    fields.append(current)
                    rows.append(fields)
                    fields = []
                    current = ""
                    // \r\n を1行末として扱う
                    if next < text.endIndex && text[next] == "\n" {
                        i = next
                    }
                case "\n":
                    fields.append(current)
                    rows.append(fields)
                    fields = []
                    current = ""
                default:
                    current.append(c)
                }
            }
            i = text.index(after: i)
        }

        // 末尾に改行がない場合の残りをflush
        if !current.isEmpty || !fields.isEmpty {
            fields.append(current)
            rows.append(fields)
        }

        return rows
    }
}
