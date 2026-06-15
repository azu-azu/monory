import Foundation

struct CinemaTicketResult {
    var movieTitle: String?
    var theaterName: String?
    var screenNumber: String?
    var seatNumber: String?
    var watchedAt: Date?
    var screeningFormat: String?
}

enum CinemaTicketParser {

    // MARK: - Keyword lists

    private static let titleKeywords = ["作品名", "映画名", "タイトル", "作品"]
    private static let theaterKeywords = ["劇場名", "劇場", "会場", "映画館"]
    private static let theaterChains = [
        "TOHOシネマズ", "イオンシネマ", "ユナイテッドシネマ", "シネマサンシャイン",
        "グランドシネマ", "109シネマズ", "OSシネマズ", "ムービックス",
        "バルト", "T・ジョイ", "シネプレックス", "ミッドランドスクエア",
    ]
    private static let screenKeywords = ["スクリーン", "Screen", "ホール"]
    private static let seatKeywords = ["座席", "席番号", "Seat"]

    // MARK: - Regex (static to avoid re-construction)

    private static let screenRegex = try? NSRegularExpression(
        pattern: #"スクリーン\s*([0-9０-９]+)|Screen\s*([0-9]+)|([0-9]+)\s*番スクリーン|第\s*([0-9]+)\s*スクリーン"#
    )
    private static let seatRegex = try? NSRegularExpression(
        pattern: #"([A-Za-z][\-\s]?\d{1,3})(?!\d)"#
    )
    private static let dateRegexes: [NSRegularExpression] = [
        #"(\d{4})[/.\-](\d{1,2})[/.\-](\d{1,2})"#,
        #"(\d{4})年(\d{1,2})月(\d{1,2})日"#,
    ].compactMap { try? NSRegularExpression(pattern: $0) }

    private static let timeRegex = try? NSRegularExpression(pattern: #"(\d{1,2}):(\d{2})"#)

    private static let formatMap: [(keyword: String, format: String)] = [
        ("IMAX", "IMAX"),
        ("MX4D", "MX4D"),
        ("4DX", "4DX"),
        ("Dolby Cinema", "Dolby Cinema"),
        ("DOLBY ATMOS", "Dolby Cinema"),
        ("ScreenX", "ScreenX"),
    ]

    // MARK: - Public

    static func parse(_ text: String) -> CinemaTicketResult {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var result = CinemaTicketResult()
        result.movieTitle = extractValue(from: lines, keywords: titleKeywords)
                         ?? extractMovieTitleFallback(from: lines)
        result.theaterName = extractTheaterName(from: lines)
        result.screenNumber = extractScreenNumber(from: lines, text: text)
        result.seatNumber = extractSeatNumber(from: lines, text: text)
        result.watchedAt = extractDate(from: text)
        result.screeningFormat = extractScreeningFormat(from: text)
        return result
    }

    // MARK: - Private helpers

    /// "keyword：value" (same line) または keyword 単独行の次行を返す
    private static func extractValue(from lines: [String], keywords: [String]) -> String? {
        let separators = CharacterSet(charactersIn: "：:　").union(.whitespaces)
        for (i, line) in lines.enumerated() {
            for keyword in keywords {
                if line.hasPrefix(keyword) {
                    let rest = String(line.dropFirst(keyword.count))
                        .trimmingCharacters(in: separators)
                    if !rest.isEmpty { return rest }
                    // value on next line
                    if i + 1 < lines.count { return lines[i + 1] }
                }
                // keyword as standalone label on a line
                if line == keyword, i + 1 < lines.count {
                    return lines[i + 1]
                }
            }
        }
        return nil
    }

    /// TOHO 等、キーワードなしで日付行の直後にタイトルが来る形式向けフォールバック
    private static func extractMovieTitleFallback(from lines: [String]) -> String? {
        for (i, line) in lines.enumerated() {
            let lineRange = NSRange(line.startIndex..., in: line)
            let hasDate = dateRegexes.contains { $0.firstMatch(in: line, range: lineRange) != nil }
            guard hasDate else { continue }
            // 日付行の直後から最大2行チェック
            for j in (i + 1)..<min(i + 3, lines.count) {
                if isLikelyMovieTitle(lines[j]) { return lines[j] }
            }
        }
        return nil
    }

    private static func isLikelyMovieTitle(_ line: String) -> Bool {
        guard line.count > 3 else { return false }
        // 価格・URL・既知の非タイトルラベルは除外
        if line.contains("円") || line.contains("¥") || line.contains("￥") { return false }
        if line.contains("://") || (line.contains(".") && !line.contains("・") && line.count < 30) { return false }
        let nonTitlePrefixes = ["スクリーン", "Screen", "座席", "Purchase", "ご購入",
                                "チケット", "予約番号", "入場", "鑑賞日時", "劇場", "作品名"]
        if nonTitlePrefixes.contains(where: { line.hasPrefix($0) }) { return false }
        // 数字だけの行は除外
        if line.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }) { return false }
        // 日本語（かな・漢字）を含むか、ラテン文字5文字以上
        let hasJapanese = line.unicodeScalars.contains { $0.value >= 0x3000 && $0.value <= 0x9FFF }
        let hasLatin = line.filter { $0.isLetter }.count > 5
        return hasJapanese || hasLatin
    }

    private static func extractTheaterName(from lines: [String]) -> String? {
        // Try keyword-based first
        if let name = extractValue(from: lines, keywords: theaterKeywords) { return name }
        // Fall back: detect known chain names as standalone or prefix
        for line in lines {
            for chain in theaterChains where line.contains(chain) {
                return line
            }
        }
        return nil
    }

    private static func extractScreenNumber(from lines: [String], text: String) -> String? {
        // Try keyword-based (same/next line)
        if let raw = extractValue(from: lines, keywords: screenKeywords) {
            // Strip "スクリーン" prefix if the value includes it
            for kw in screenKeywords where raw.hasPrefix(kw) {
                return String(raw.dropFirst(kw.count)).trimmingCharacters(in: .whitespaces)
            }
            return raw
        }
        // Regex fallback: "スクリーン7", "Screen 7", "7番スクリーン"
        guard let regex = screenRegex else { return nil }
        let ns = text as NSString
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        for i in 1..<match.numberOfRanges {
            let r = match.range(at: i)
            if r.location != NSNotFound { return ns.substring(with: r) }
        }
        return nil
    }

    private static func extractSeatNumber(from lines: [String], text: String) -> String? {
        // Try keyword-based
        if let raw = extractValue(from: lines, keywords: seatKeywords) { return raw }
        // Regex fallback: "E-10", "E10", "E 10"
        guard let regex = seatRegex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (text as NSString).substring(with: match.range(at: 1))
    }

    private static func extractDate(from text: String) -> Date? {
        let ns = text as NSString
        let textRange = NSRange(text.startIndex..., in: text)
        for regex in dateRegexes {
            guard let match = regex.firstMatch(in: text, range: textRange),
                  match.numberOfRanges >= 4,
                  let y = Int(ns.substring(with: match.range(at: 1))),
                  let m = Int(ns.substring(with: match.range(at: 2))),
                  let d = Int(ns.substring(with: match.range(at: 3))) else { continue }
            var components = DateComponents()
            components.year = y; components.month = m; components.day = d
            if let timeRegex,
               let timeMatch = timeRegex.firstMatch(in: text, range: textRange),
               timeMatch.numberOfRanges >= 3 {
                components.hour = Int(ns.substring(with: timeMatch.range(at: 1)))
                components.minute = Int(ns.substring(with: timeMatch.range(at: 2)))
            }
            return Calendar.current.date(from: components)
        }
        return nil
    }

    private static func extractScreeningFormat(from text: String) -> String? {
        let upper = text.uppercased()
        for entry in formatMap where upper.contains(entry.keyword.uppercased()) {
            return entry.format
        }
        return nil
    }
}
