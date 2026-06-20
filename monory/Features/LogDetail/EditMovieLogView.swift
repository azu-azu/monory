import SwiftUI
import SwiftData
import PhotosUI

struct EditMovieLogView: View {
    let log: MovieLog

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(StreamingServiceStore.self) private var streamingStore

    @State private var movieTitle: String
    @State private var watchedAt: Date
    @State private var viewingType: ViewingType
    @State private var theaterName: String
    @State private var screenNumber: String
    @State private var seatNumber: String
    @State private var screeningFormat: ScreeningFormat
    @State private var streamingService: String
    @State private var customStreamingService: String
    @State private var rating: Int?
    @State private var review: String
    @State private var watchedAtUnknown: Bool
    @State private var additionalDates: [IdentifiableDate]
    @State private var admissionFeeText: String

    @State private var selectedTicketItems: [PhotosPickerItem] = []

    @State private var ocrResult: CinemaTicketResult?
    @State private var showOCRSheet = false
    @State private var showRescanEmptyAlert = false
    @State private var isScanning = false

    init(log: MovieLog) {
        self.log = log
        _movieTitle     = State(initialValue: log.movieTitle)
        _watchedAt      = State(initialValue: log.watchedAt)
        _viewingType    = State(initialValue: ViewingType(rawValue: log.viewingType) ?? .theater)
        _theaterName    = State(initialValue: log.theaterName)
        _screenNumber   = State(initialValue: log.screenNumber ?? "")
        _seatNumber     = State(initialValue: log.seatNumber ?? "")
        _screeningFormat = State(initialValue: ScreeningFormat(rawValue: log.screeningFormat) ?? .standard)
        _rating             = State(initialValue: log.rating)
        _review             = State(initialValue: log.review)
        _watchedAtUnknown   = State(initialValue: log.watchedAtUnknown)
        _additionalDates = State(initialValue:
            log.viewingDates
                .sorted(by: { $0.date < $1.date })
                .map { IdentifiableDate(date: $0.date) }
        )
        _admissionFeeText = State(initialValue: log.admissionFee.map { String($0) } ?? "")

        // streaming service: preset か custom かを判定
        let knownServices = StreamingServiceStore.loadServices()
        let stored = log.streamingService ?? (knownServices.first ?? "Netflix")
        if knownServices.contains(stored) {
            _streamingService       = State(initialValue: stored)
            _customStreamingService = State(initialValue: "")
        } else {
            _streamingService       = State(initialValue: StreamingServiceStore.otherOption)
            _customStreamingService = State(initialValue: stored)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("作品") {
                    LabeledContent("タイトル") {
                        TextField("映画タイトル", text: $movieTitle)
                            .multilineTextAlignment(.trailing)
                    }
                    if viewingType == .theater {
                        if !watchedAtUnknown {
                            DatePicker("観た日", selection: $watchedAt, displayedComponents: .date)
                        }
                        Toggle("日付不明", isOn: $watchedAtUnknown)
                    }
                }

                Section {
                    ViewingTypeToggle(selection: $viewingType)
                }

                if viewingType == .theater {
                    Section("映画館") {
                        TextField("映画館名", text: $theaterName)
                        TextField("スクリーン番号", text: $screenNumber)
                        TextField("座席番号", text: $seatNumber)
                        LabeledContent("料金") {
                            TextField("0", text: $admissionFeeText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        Picker("上映形式", selection: $screeningFormat) {
                            ForEach(ScreeningFormat.allCases, id: \.self) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                    }
                } else {
                    Section("メディア") {
                        Picker("サービス", selection: $streamingService) {
                            ForEach(streamingStore.services, id: \.self) { service in
                                Text(service).tag(service)
                            }
                            Text(StreamingServiceStore.otherOption)
                                .tag(StreamingServiceStore.otherOption)
                        }
                        if streamingService == StreamingServiceStore.otherOption {
                            TextField("サービス名", text: $customStreamingService)
                        }
                    }

                    Section("視聴日") {
                        if !watchedAtUnknown {
                            DatePicker("初回", selection: $watchedAt, displayedComponents: .date)
                            ForEach($additionalDates) { $item in
                                HStack {
                                    DatePicker("", selection: $item.date, displayedComponents: .date)
                                        .labelsHidden()
                                    Spacer()
                                    Button {
                                        additionalDates.removeAll { $0.id == item.id }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            Button {
                                additionalDates.append(IdentifiableDate(date: Date()))
                            } label: {
                                Label("視聴日を追加", systemImage: "plus.circle")
                            }
                        }
                        Toggle("日付不明", isOn: $watchedAtUnknown)
                    }
                }

                Section("評価") {
                    HStack {
                        StarRatingView(rating: rating, editing: true) { selected in
                            rating = selected
                        }
                        Spacer()
                        if rating != nil {
                            Button("クリア") { rating = nil }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("感想") {
                    TextField("感想を書く...", text: $review, axis: .vertical)
                        .lineLimit(5...10)
                        .keyboardCloseToolbar()
                }

                if viewingType == .theater {
                    Section("チケット画像") {
                        PhotosPicker(selection: $selectedTicketItems, matching: .images) {
                            Label("画像を追加", systemImage: "plus.circle")
                        }
                        if !log.ticketImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(log.ticketImages) { ticket in
                                        if let uiImage = UIImage(data: ticket.imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipped()
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            Button {
                                Task { await rescan() }
                            } label: {
                                if isScanning {
                                    Label("読み取り中...", systemImage: "arrow.clockwise")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Label("画像をもう一度読み取る", systemImage: "arrow.clockwise")
                                }
                            }
                            .disabled(isScanning)
                        }
                    }
                }
            }
            .navigationTitle("記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(movieTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: selectedTicketItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    await addTicketImages(newItems)
                    selectedTicketItems = []
                }
            }
            .sheet(isPresented: $showOCRSheet) {
                if let result = ocrResult {
                    OCRResultSheet(result: result) { field in
                        applyOCRField(field)
                    }
                }
            }
            .alert("読み取れませんでした", isPresented: $showRescanEmptyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("チケット画像から情報を読み取れませんでした。")
            }
        }
    }

    // MARK: - Private

    private func addTicketImages(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let ticket = TicketImage(imageData: data)
            ticket.ocrRawText = await OCRService.recognizeText(from: data)
            context.insert(ticket)
            log.ticketImages.append(ticket)
        }
        await rescan()
    }

    private func rescan() async {
        isScanning = true
        defer { isScanning = false }

        var merged = CinemaTicketResult()
        for ticket in log.ticketImages {
            let text: String?
            if let stored = ticket.ocrRawText {
                text = stored
            } else {
                text = await OCRService.recognizeText(from: ticket.imageData)
            }
            guard let t = text else { continue }
            let parsed = CinemaTicketParser.parse(t)
            if merged.movieTitle == nil     { merged.movieTitle = parsed.movieTitle }
            if merged.theaterName == nil    { merged.theaterName = parsed.theaterName }
            if merged.screenNumber == nil   { merged.screenNumber = parsed.screenNumber }
            if merged.seatNumber == nil     { merged.seatNumber = parsed.seatNumber }
            if merged.watchedAt == nil      { merged.watchedAt = parsed.watchedAt }
            if merged.screeningFormat == nil { merged.screeningFormat = parsed.screeningFormat }
            if merged.admissionFee == nil   { merged.admissionFee = parsed.admissionFee }
        }
        ocrResult = merged
        let hasAnyResult = merged.movieTitle != nil || merged.theaterName != nil
            || merged.screenNumber != nil || merged.seatNumber != nil
            || merged.watchedAt != nil || merged.screeningFormat != nil
            || merged.admissionFee != nil
        if hasAnyResult {
            showOCRSheet = true
        } else {
            showRescanEmptyAlert = true
        }
    }

    private func applyOCRField(_ field: OCRResultSheet.OCRField) {
        switch field {
        case .movieTitle(let v):      movieTitle = v
        case .theaterName(let v):     theaterName = v
        case .screenNumber(let v):    screenNumber = v
        case .seatNumber(let v):      seatNumber = v
        case .watchedAt(let v):       watchedAt = v; watchedAtUnknown = false
        case .screeningFormat(let v): screeningFormat = v
        case .admissionFee(let v):    admissionFeeText = String(v)
        }
    }

    private func saveChanges() {
        log.movieTitle        = movieTitle.trimmingCharacters(in: .whitespaces)
        log.watchedAt         = watchedAt
        log.watchedAtUnknown  = watchedAtUnknown
        log.rating            = rating
        log.viewingType       = viewingType.rawValue
        log.review            = review.trimmingCharacters(in: .whitespaces)
        log.updatedAt         = Date()

        if viewingType == .theater {
            log.theaterName     = theaterName.trimmingCharacters(in: .whitespaces)
            log.screenNumber    = screenNumber.isEmpty ? nil : screenNumber
            log.seatNumber      = seatNumber.isEmpty ? nil : seatNumber
            log.screeningFormat = screeningFormat.rawValue
            log.admissionFee = admissionFeeText.isEmpty ? nil : Int(admissionFeeText.filter { $0.isNumber })
            log.streamingService = nil
            // 映画館に切り替えた場合、配信日付を削除
            for vd in log.viewingDates { context.delete(vd) }
        } else {
            let service = streamingService == StreamingServiceStore.otherOption
                ? customStreamingService
                : streamingService
            log.streamingService = service.isEmpty ? nil : service
            log.theaterName     = ""
            log.screenNumber    = nil
            log.seatNumber      = nil

            // 追加視聴日を書き戻し（既存を全削除→再作成）
            for vd in log.viewingDates { context.delete(vd) }
            for item in additionalDates {
                let vd = ViewingDate(date: item.date)
                context.insert(vd)
                log.viewingDates.append(vd)
            }
        }
    }
}
