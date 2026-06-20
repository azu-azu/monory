import Foundation

struct CinemaTicketResult {
    var movieTitle: String?
    var theaterName: String?
    var screenNumber: String?
    var seatNumber: String?
    var watchedAt: Date?
    var screeningFormat: String?
    var admissionFee: Int?

    var hasAnyResult: Bool {
        movieTitle != nil || theaterName != nil || screenNumber != nil
            || seatNumber != nil || watchedAt != nil
            || screeningFormat != nil || admissionFee != nil
    }
}

enum CinemaTicketParser {

    // MARK: - Unicode ranges

    private static let japaneseScalarStart: UInt32 = 0x3000  // CJK記号・句読点
    private static let japaneseScalarEnd:   UInt32 = 0x9FFF  // CJK統合漢字
    private static let fullWidthDigitStart: UInt32 = 0xFF10  // '０'
    private static let fullWidthDigitEnd:   UInt32 = 0xFF19  // '９'
    private static let halfWidthDigitBase:  UInt32 = 0x30    // '0'

    // MARK: - Admission fee bounds

    private static let minAdmissionFee = 300    // 最安映画料金の目安
    private static let maxAdmissionFee = 9_999  // 5桁以上は誤 OCR と判断

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
    private static let feeKeywords = ["料金", "金額", "入場料", "チケット代", "代金", "販売価格"]

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
    // ¥1,800 / ￥1800 / 1,800円 など
    private static let feeRegex = try? NSRegularExpression(
        pattern: #"[¥￥]\s*([0-9０-９][0-9０-９,，]*)|([0-9０-９][0-9０-９,，]*)\s*円"#
    )

    private static let formatMap: [(keyword: String, format: String)] = [
        ("IMAX", "IMAX"),
        ("MX4D", "MX4D"),
        ("4DX", "4DX"),
        ("Dolby Cinema", "Dolby Cinema"),
        ("DOLBY ATMOS", "Dolby Cinema"),
        ("ScreenX", "ScreenX"),
    ]

    /// チケットタイトルから上映修飾語を除去する
    /// 例: 「プロジェクト・ヘイル・メリー【IMAXレーザーGT字幕】」→「プロジェクト・ヘイル・メリー」
    ///     「Michael/マイケル（IMAXレーザー・字幕」（閉じ括弧なし）→「Michael/マイケル」
    static func normalizeTitle(_ title: String) -> String {
        var result = title
        // 完全なカッコペア: 「（...字幕...）」「【...吹替...】」など
        result = stripAll(
            result,
            pattern: #"[\s　]*[（\(\[【「][^）\)\]】」]*(?:字幕|吹替|吹き替え)[^）\)\]】」]*[）\)\]】」]"#
        )
        // 閉じカッコなしで末尾まで続く場合（OCRで折り返された時）:「（IMAX字幕」
        result = stripAll(
            result,
            pattern: #"[\s　]*[（\(\[【「][^）\)\]】」]*(?:字幕|吹替|吹き替え).*$"#
        )
        // カッコなしの末尾ノイズ: " 字幕版"、"　吹替" など
        result = stripAll(result, pattern: #"[\s　]+(?:字幕版?|吹替版?|吹き替え版?)$"#)
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func stripAll(_ string: String, pattern: String) -> String {
        var result = string
        while let range = result.range(of: pattern, options: .regularExpression) {
            result.removeSubrange(range)
        }
        return result
    }

    // MARK: - Public

    static func parse(_ text: String) -> CinemaTicketResult {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var result = CinemaTicketResult()
        result.movieTitle = (extractValue(from: lines, keywords: titleKeywords)
                         ?? extractMovieTitleFallback(from: lines))
                         .map { normalizeTitle($0) }
        result.theaterName = extractTheaterName(from: lines)
        result.screenNumber = extractScreenNumber(from: lines, text: text)
        result.seatNumber = extractSeatNumber(from: lines, text: text)
        result.watchedAt = extractDate(from: text)
        result.screeningFormat = extractScreeningFormat(from: text)
        result.admissionFee = extractAdmissionFee(from: lines, text: text)
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
                    if !rest.isEmpty {
                        return joinIfUnclosed(rest, next: i + 1 < lines.count ? lines[i + 1] : nil)
                    }
                    // value on next line
                    if i + 1 < lines.count {
                        return joinIfUnclosed(lines[i + 1], next: i + 2 < lines.count ? lines[i + 2] : nil)
                    }
                }
            }
        }
        return nil
    }

    /// 開き括弧が閉じ括弧より多い（= OCR が行中で折り返した）場合のみ next を結合する
    private static func joinIfUnclosed(_ base: String, next: String?) -> String {
        guard let next else { return base }
        let opens  = base.unicodeScalars.filter { "（([【「".unicodeScalars.contains($0) }.count
        let closes = base.unicodeScalars.filter { "）)】」]".unicodeScalars.contains($0) }.count
        return opens > closes ? base + next : base
    }

    /// TOHO 等、キーワードなしで日付行の直後にタイトルが来る形式向けフォールバック
    private static func extractMovieTitleFallback(from lines: [String]) -> String? {
        for (i, line) in lines.enumerated() {
            let lineRange = NSRange(line.startIndex..., in: line)
            let hasDate = dateRegexes.contains { $0.firstMatch(in: line, range: lineRange) != nil }
            guard hasDate else { continue }
            // 日付行の直後から最大2行チェック
            for j in (i + 1)..<min(i + 3, lines.count) {
                if isLikelyMovieTitle(lines[j]) {
                    return joinIfUnclosed(lines[j], next: j + 1 < lines.count ? lines[j + 1] : nil)
                }
            }
        }
        return nil
    }

    private static func isLikelyMovieTitle(_ line: String) -> Bool {
        guard line.count > 3 else { return false }
        // 価格・URL・既知の非タイトルラベルは除外
        if line.contains("円") || line.contains("¥") || line.contains("￥") { return false }
        if line.contains("://") || line.hasSuffix(".jp") || line.hasSuffix(".com") { return false }
        let nonTitlePrefixes = ["スクリーン", "Screen", "座席", "Purchase", "ご購入",
                                "チケット", "予約番号", "入場", "鑑賞日時", "劇場", "作品名"]
        if nonTitlePrefixes.contains(where: { line.hasPrefix($0) }) { return false }
        // 数字だけの行は除外
        if line.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }) { return false }
        // 日本語（かな・漢字）を含むか、ラテン文字5文字以上
        let hasJapanese = line.unicodeScalars.contains { $0.value >= japaneseScalarStart && $0.value <= japaneseScalarEnd }
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

    /// チケットから料金（円）を抽出する。合理的な映画料金範囲（300〜9999円）に絞る
    private static func extractAdmissionFee(from lines: [String], text: String) -> Int? {
        // 1. キーワードベース: 「料金：1,800円」「金額 ¥1800」など
        if let raw = extractValue(from: lines, keywords: feeKeywords) {
            if let fee = parseYen(from: raw), isReasonableFee(fee) { return fee }
        }
        // 2. regex fallback: テキスト全体から ¥/円 を含む数字を全候補取得し、最初の合理的値を採用
        guard let regex = feeRegex else { return nil }
        let ns = text as NSString
        let range = NSRange(text.startIndex..., in: text)
        var matches = [Int]()
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match else { return }
            for i in 1..<match.numberOfRanges {
                let r = match.range(at: i)
                if r.location != NSNotFound {
                    let s = ns.substring(with: r)
                    if let fee = parseYen(from: s) { matches.append(fee) }
                }
            }
        }
        return matches.first(where: isReasonableFee)
    }

    /// 数字文字列（カンマ・全角混じり可）を Int に変換する
    private static func parseYen(from raw: String) -> Int? {
        let digits = raw
            .unicodeScalars
            .compactMap { s -> Character? in
                if s.value >= fullWidthDigitStart && s.value <= fullWidthDigitEnd {
                    // 全角数字 → 半角
                    return Character(UnicodeScalar(s.value - fullWidthDigitStart + halfWidthDigitBase)!)
                }
                let c = Character(s)
                return (c.isNumber || c == ",") ? c : nil
            }
            .filter { $0 != "," }
        return Int(String(digits))
    }

    private static func isReasonableFee(_ fee: Int) -> Bool {
        fee >= minAdmissionFee && fee <= maxAdmissionFee
    }
}
