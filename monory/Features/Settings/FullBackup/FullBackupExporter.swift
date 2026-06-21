import Foundation
import ZIPFoundation

struct FullBackupExporter {
    static let currentFormatVersion = 1

    // MARK: - Public API

    /// @MainActor で呼ぶ。@Model → Sendable Snapshot へコピー。
    @MainActor
    static func makeSnapshot(logs: [MovieLog]) -> BackupSnapshot {
        let settings = SettingsDTO(
            streamingServiceOrder: StreamingServiceStore.loadServices()
        )

        let entries: [BackupSnapshot.LogEntry] = logs.map { log in
            let posterExt = log.moviePosterData.map { imageExtension(for: $0) }

            let ticketEntries: [(filename: String, data: Data)] = log.ticketImages.map { ticket in
                let ext = imageExtension(for: ticket.imageData)
                return (filename: "\(ticket.id.uuidString).\(ext)", data: ticket.imageData)
            }

            let ticketDTOs: [TicketImageDTO] = log.ticketImages.map { ticket in
                TicketImageDTO(
                    id: ticket.id.uuidString,
                    createdAt: ticket.createdAt,
                    ocrRawText: ticket.ocrRawText,
                    imageExt: imageExtension(for: ticket.imageData)
                )
            }

            let viewingDateDTOs: [ViewingDateDTO] = log.viewingDates.map { vd in
                ViewingDateDTO(id: vd.id.uuidString, date: vd.date)
            }

            let dto = MovieLogDTO(
                id: log.id.uuidString,
                watchedAt: log.watchedAt,
                movieTitle: log.movieTitle,
                theaterName: log.theaterName,
                review: log.review,
                screenNumber: log.screenNumber,
                seatNumber: log.seatNumber,
                screeningFormat: log.screeningFormat,
                admissionFee: log.admissionFee,
                viewingType: log.viewingType,
                streamingService: log.streamingService,
                tmdbId: log.tmdbId,
                movieOriginalTitle: log.movieOriginalTitle,
                movieReleaseYear: log.movieReleaseYear,
                movieSynopsis: log.movieSynopsis,
                posterImageExt: posterExt,
                watchedAtUnknown: log.watchedAtUnknown,
                watchedYearOnly: log.watchedYearOnly,
                theaterMemo: log.theaterMemo,
                rating: log.rating,
                createdAt: log.createdAt,
                updatedAt: log.updatedAt,
                ticketImages: ticketDTOs,
                viewingDates: viewingDateDTOs,
                movieRuntimeMinutes: log.movieRuntimeMinutes,
                movieGenresRaw: log.movieGenresRaw,
                movieDirector: log.movieDirector,
                movieCastRaw: log.movieCastRaw,
                metadataUpdatedAt: log.metadataUpdatedAt
            )

            return BackupSnapshot.LogEntry(
                dto: dto,
                posterData: log.moviePosterData,
                tickets: ticketEntries
            )
        }

        return BackupSnapshot(logs: entries, settings: settings)
    }

    /// background で ZIP を生成し、temporary URL を返す。
    static func export(snapshot: BackupSnapshot) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            try createArchive(snapshot: snapshot)
        }.value
    }

    // MARK: - Core (sync)

    private static func createArchive(snapshot: BackupSnapshot) throws -> URL {
        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: tmpDir) }

        let postersDir = tmpDir.appendingPathComponent("images/posters")
        let ticketsDir = tmpDir.appendingPathComponent("images/tickets")

        try fm.createDirectory(at: postersDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: ticketsDir, withIntermediateDirectories: true)

        // 画像ファイルを書き出す
        for entry in snapshot.logs {
            if let data = entry.posterData {
                let ext = entry.dto.posterImageExt ?? "bin"
                let dest = postersDir.appendingPathComponent("\(entry.dto.id).\(ext)")
                try data.write(to: dest)
            }
            for ticket in entry.tickets {
                let dest = ticketsDir.appendingPathComponent(ticket.filename)
                try ticket.data.write(to: dest)
            }
        }

        // JSON を書き出す
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let manifest = BackupManifest(
            formatVersion: currentFormatVersion,
            exportedAt: Date(),
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        )
        try encoder.encode(manifest).write(to: tmpDir.appendingPathComponent("manifest.json"))
        try encoder.encode(snapshot.logs.map(\.dto)).write(to: tmpDir.appendingPathComponent("logs.json"))
        try encoder.encode(snapshot.settings).write(to: tmpDir.appendingPathComponent("settings.json"))

        // ZIP 化
        let dateStr = isoDateString()
        let zipURL = fm.temporaryDirectory.appendingPathComponent("monory-backup-\(dateStr).zip")
        if fm.fileExists(atPath: zipURL.path) {
            try fm.removeItem(at: zipURL)
        }
        try fm.zipItem(at: tmpDir, to: zipURL, shouldKeepParent: false)
        try? fm.removeItem(at: tmpDir)
        try fm.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: zipURL.path
        )

        return zipURL
    }

    // MARK: - Helpers

    static func imageExtension(for data: Data) -> String {
        if data.prefix(3) == Data([0xFF, 0xD8, 0xFF]) { return "jpg" }
        if data.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return "png" }
        return "bin"
    }

    private static func isoDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }
}
