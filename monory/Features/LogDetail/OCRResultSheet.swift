import SwiftUI

struct OCRResultSheet: View {

    // Hashable: associated value は無視して case の種類だけで同一性を判定する
    // （同じフィールドを2回適用してもチェックマークは1つ）
    enum OCRField: Hashable {
        case movieTitle(String)
        case theaterName(String)
        case screenNumber(String)
        case seatNumber(String)
        case watchedAt(Date)
        case screeningFormat(ScreeningFormat)
        case admissionFee(Int)

        static func == (lhs: OCRField, rhs: OCRField) -> Bool {
            switch (lhs, rhs) {
            case (.movieTitle, .movieTitle),
                 (.theaterName, .theaterName),
                 (.screenNumber, .screenNumber),
                 (.seatNumber, .seatNumber),
                 (.watchedAt, .watchedAt),
                 (.screeningFormat, .screeningFormat),
                 (.admissionFee, .admissionFee): return true
            default: return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case .movieTitle:      hasher.combine(0)
            case .theaterName:     hasher.combine(1)
            case .screenNumber:    hasher.combine(2)
            case .seatNumber:      hasher.combine(3)
            case .watchedAt:       hasher.combine(4)
            case .screeningFormat: hasher.combine(5)
            case .admissionFee:    hasher.combine(6)
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    let result: CinemaTicketResult
    var onApply: (OCRField) -> Void

    @State private var applied: Set<OCRField> = []

    private var resolvedFormat: ScreeningFormat? {
        guard let s = result.screeningFormat else { return nil }
        return ScreeningFormat.allCases.first { $0.rawValue == s }
    }

    var body: some View {
        NavigationStack {
            List {
                fieldRow(label: "タイトル",
                         display: result.movieTitle,
                         field: result.movieTitle.map { .movieTitle($0) })
                fieldRow(label: "映画館",
                         display: result.theaterName,
                         field: result.theaterName.map { .theaterName($0) })
                fieldRow(label: "スクリーン番号",
                         display: result.screenNumber,
                         field: result.screenNumber.map { .screenNumber($0) })
                fieldRow(label: "座席番号",
                         display: result.seatNumber,
                         field: result.seatNumber.map { .seatNumber($0) })
                fieldRow(label: "観た日",
                         display: result.watchedAt.map { $0.formatted(date: .long, time: .omitted) },
                         field: result.watchedAt.map { .watchedAt($0) })
                fieldRow(label: "上映形式",
                         display: resolvedFormat?.rawValue,
                         field: resolvedFormat.map { .screeningFormat($0) })
                fieldRow(label: "料金",
                         display: result.admissionFee.map { "¥\($0)" },
                         field: result.admissionFee.map { .admissionFee($0) })

            }
            .navigationTitle("チケットから読み取り")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("すべて適用") {
                        applyAll()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func fieldRow(label: String, display: String?, field: OCRField?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let display {
                    Text(display)
                } else {
                    Text("読み取れませんでした")
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
            Spacer()
            if let f = field {
                if applied.contains(f) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("適用") {
                        onApply(f)
                        applied.insert(f)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private func applyAll() {
        let fields: [OCRField?] = [
            result.movieTitle.map    { .movieTitle($0) },
            result.theaterName.map   { .theaterName($0) },
            result.screenNumber.map  { .screenNumber($0) },
            result.seatNumber.map    { .seatNumber($0) },
            result.watchedAt.map     { .watchedAt($0) },
            resolvedFormat.map       { .screeningFormat($0) },
            result.admissionFee.map  { .admissionFee($0) },
        ]
        for case let f? in fields {
            onApply(f)
            applied.insert(f)
        }
    }
}
