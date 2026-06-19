import Foundation
import SwiftData

struct MovieLogImporter {
    struct ImportResult {
        let importedCount: Int
        let skippedCount: Int
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func `import`(data: Data, into context: ModelContext) -> ImportResult {
        // UTF-8 BOM を除去
        var csvData = data
        if csvData.prefix(3) == Data([0xEF, 0xBB, 0xBF]) {
            csvData = csvData.dropFirst(3)
        }
        guard let text = String(data: csvData, encoding: .utf8) else {
            return ImportResult(importedCount: 0, skippedCount: 0)
        }

        var rows = parseCSV(text)
        guard rows.count > 1 else { return ImportResult(importedCount: 0, skippedCount: 0) }
        rows.removeFirst() // header row

        var imported = 0
        var skipped = 0

        for row in rows {
            // 空行・列数不足はスキップ（末尾の空行も含む）
            guard row.count >= 14, !row[0].isEmpty else {
                if !row.allSatisfy({ $0.isEmpty }) { skipped += 1 }
                continue
            }

            let watchedAtStr = row[3]
            let isUnknown = watchedAtStr == "不明"
            let watchedAt = isUnknown ? Date() : (dateFormatter.date(from: watchedAtStr) ?? Date())

            let log = MovieLog(
                watchedAt: watchedAt,
                movieTitle: row[0],
                theaterName: row[6],
                review: row[12]
            )
            log.movieOriginalTitle  = row[1].isEmpty ? nil : row[1]
            log.movieReleaseYear    = Int(row[2])
            log.watchedAtUnknown    = isUnknown
            log.rating              = Int(row[4])
            log.viewingType         = row[5].isEmpty ? ViewingType.theater.rawValue : row[5]
            log.streamingService    = row[7].isEmpty ? nil : row[7]
            log.screeningFormat     = row[8].isEmpty ? ScreeningFormat.standard.rawValue : row[8]
            log.screenNumber        = row[9].isEmpty ? nil : row[9]
            log.seatNumber          = row[10].isEmpty ? nil : row[10]
            log.tmdbId              = Int(row[13])

            context.insert(log)

            // 追加視聴日: "/" 区切りで複数日付
            if !row[11].isEmpty {
                for part in row[11].split(separator: "/", omittingEmptySubsequences: true) {
                    if let date = dateFormatter.date(from: String(part)) {
                        let vd = ViewingDate(date: date)
                        context.insert(vd)
                        log.viewingDates.append(vd)
                    }
                }
            }

            imported += 1
        }

        return ImportResult(importedCount: imported, skippedCount: skipped)
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
