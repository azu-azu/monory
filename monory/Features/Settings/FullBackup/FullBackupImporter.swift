import Foundation
import SwiftData
import ZIPFoundation

struct FullBackupImporter {

    // MARK: - Public API

    @MainActor
    static func restore(
        from url: URL,
        in container: ModelContainer,
        mode: ImportMode,
        serviceStore: StreamingServiceStore
    ) async throws -> ImportResult {
        // Step 1: background で I/O + decode + validate
        let payload = try await Task.detached(priority: .userInitiated) {
            try decodePayload(from: url)
        }.value

        // Step 2: 専用 context（autosave 無効）で mutation
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let result = try applyToContext(payload, into: context, mode: mode)
            try context.save()
            // settings restore は replace mode のみ
            if mode == .replace {
                serviceStore.services = payload.settings.streamingServiceOrder
            }
            return result
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: - Resource limits

    private static let maxEntryCount = 5_000
    private static let maxTotalUncompressedSize: UInt64 = 100 * 1024 * 1024  // 100 MB
    private static let maxImageSize: UInt64 = 10 * 1024 * 1024               // 10 MB
    private static let maxLogsJSONSize: UInt64 = 5 * 1024 * 1024             // 5 MB
    private static let maxLogCount = 10_000

    // MARK: - Decode + Validate (sync, Sendable を返す)

    static func decodePayload(from url: URL) throws -> BackupPayload {
        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: tmpDir) }

        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        // ZIP Slip 対策: 展開前に全 entry path を検証してから extract
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw BackupError.invalidArchive
        }

        let allowedExact = Set(["manifest.json", "logs.json", "settings.json"])
        let allowedDirPrefixes = ["images/posters/", "images/tickets/"]

        // Pass 1: path validation + resource limits（展開前）
        var entryCount = 0
        var totalUncompressed: UInt64 = 0

        for entry in archive {
            let path = entry.path
            // directory entry はスキップ（"images/" など）
            if entry.type == .directory { continue }
            // symlink は拒否
            if entry.type == .symlink { throw BackupError.invalidArchive }
            // ".." / 絶対パスを拒否
            guard !path.contains(".."), !path.hasPrefix("/") else {
                throw BackupError.invalidArchive
            }
            // 許可リスト外は拒否
            let isAllowed = allowedExact.contains(path)
                || allowedDirPrefixes.contains(where: { path.hasPrefix($0) })
            guard isAllowed else { throw BackupError.invalidArchive }

            // entry 数
            entryCount += 1
            guard entryCount <= Self.maxEntryCount else {
                throw BackupError.resourceLimitExceeded
            }

            // per-file size
            let entrySize = UInt64(entry.uncompressedSize)
            if path == "logs.json" {
                guard entrySize <= Self.maxLogsJSONSize else {
                    throw BackupError.resourceLimitExceeded
                }
            } else if allowedDirPrefixes.contains(where: { path.hasPrefix($0) }) {
                guard entrySize <= Self.maxImageSize else {
                    throw BackupError.resourceLimitExceeded
                }
            }

            // 全体サイズ（overflow-safe: 加算前に残余を確認）
            guard entrySize <= Self.maxTotalUncompressedSize,
                  totalUncompressed <= Self.maxTotalUncompressedSize - entrySize else {
                throw BackupError.resourceLimitExceeded
            }
            totalUncompressed += entrySize
        }

        // Pass 2: extract
        for entry in archive {
            let dest = tmpDir.appendingPathComponent(entry.path)
            switch entry.type {
            case .directory:
                try fm.createDirectory(at: dest, withIntermediateDirectories: true)
            case .file:
                try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                _ = try archive.extract(entry, to: dest)
            case .symlink:
                break  // Pass 1 で弾いているが念のため
            }
        }

        // manifest 検証
        let manifestURL = tmpDir.appendingPathComponent("manifest.json")
        guard fm.fileExists(atPath: manifestURL.path) else {
            throw BackupError.missingRequiredFile("manifest.json")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let manifest = try decoder.decode(BackupManifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.formatVersion == FullBackupExporter.currentFormatVersion else {
            throw BackupError.unsupportedVersion(manifest.formatVersion)
        }

        // logs.json
        let logsURL = tmpDir.appendingPathComponent("logs.json")
        guard fm.fileExists(atPath: logsURL.path) else {
            throw BackupError.missingRequiredFile("logs.json")
        }
        let logs = try decoder.decode([MovieLogDTO].self, from: Data(contentsOf: logsURL))
        guard logs.count <= Self.maxLogCount else {
            throw BackupError.resourceLimitExceeded
        }

        // settings.json（format v1 では required）
        let settingsURL = tmpDir.appendingPathComponent("settings.json")
        guard fm.fileExists(atPath: settingsURL.path) else {
            throw BackupError.missingRequiredFile("settings.json")
        }
        let settings = try decoder.decode(SettingsDTO.self, from: Data(contentsOf: settingsURL))

        // 画像を読み込む
        var imageData: [String: Data] = [:]

        func loadImages(in subDir: String) throws {
            let dir = tmpDir.appendingPathComponent(subDir)
            guard let entries = try? fm.contentsOfDirectory(atPath: dir.path) else { return }
            for filename in entries {
                let fileURL = dir.appendingPathComponent(filename)
                imageData[filename] = try Data(contentsOf: fileURL)
            }
        }
        try loadImages(in: "images/posters")
        try loadImages(in: "images/tickets")

        let payload = BackupPayload(manifest: manifest, logs: logs, settings: settings, imageData: imageData)

        // apply 前に全 UUID・参照 image を検証
        try validatePayload(payload)

        return payload
    }

    // MARK: - Validation

    private static func validatePayload(_ payload: BackupPayload) throws {
        for dto in payload.logs {
            guard UUID(uuidString: dto.id) != nil else {
                throw BackupError.invalidArchive
            }
            // poster が指定されているなら対応 file が必須
            if let ext = dto.posterImageExt {
                guard payload.imageData["\(dto.id).\(ext)"] != nil else {
                    throw BackupError.invalidArchive
                }
            }
            for ticketDTO in dto.ticketImages {
                guard UUID(uuidString: ticketDTO.id) != nil else {
                    throw BackupError.invalidArchive
                }
                guard payload.imageData["\(ticketDTO.id).\(ticketDTO.imageExt)"] != nil else {
                    throw BackupError.invalidArchive
                }
            }
            for vdDTO in dto.viewingDates {
                guard UUID(uuidString: vdDTO.id) != nil else {
                    throw BackupError.invalidArchive
                }
            }
        }
    }

    // MARK: - Apply to Context (sync)

    private static func applyToContext(
        _ payload: BackupPayload,
        into context: ModelContext,
        mode: ImportMode
    ) throws -> ImportResult {
        switch mode {
        case .replace:
            return try applyReplace(payload, into: context)
        case .merge:
            return try applyMerge(payload, into: context)
        }
    }

    private static func applyReplace(_ payload: BackupPayload, into context: ModelContext) throws -> ImportResult {
        try context.delete(model: MovieLog.self)

        var count = 0
        for dto in payload.logs {
            let log = buildLog(from: dto, imageData: payload.imageData, context: context)
            context.insert(log)
            count += 1
        }
        return ImportResult(restoredCount: count, updatedCount: 0, skippedCount: 0)
    }

    private static func applyMerge(_ payload: BackupPayload, into context: ModelContext) throws -> ImportResult {
        var restored = 0
        var updated = 0
        var skipped = 0

        for dto in payload.logs {
            guard let logId = UUID(uuidString: dto.id) else { continue }
            let predicate = #Predicate<MovieLog> { $0.id == logId }
            let existing = try context.fetch(FetchDescriptor<MovieLog>(predicate: predicate))

            if let log = existing.first {
                // newer wins: backup が古ければスキップ、同一 timestamp はローカル優先
                guard dto.updatedAt > log.updatedAt else {
                    skipped += 1
                    continue
                }
                updateLog(log, from: dto, imageData: payload.imageData, context: context)
                updated += 1
            } else {
                let log = buildLog(from: dto, imageData: payload.imageData, context: context)
                context.insert(log)
                restored += 1
            }
        }
        return ImportResult(restoredCount: restored, updatedCount: updated, skippedCount: skipped)
    }

    // MARK: - Build / Update Helpers

    private static func buildLog(
        from dto: MovieLogDTO,
        imageData: [String: Data],
        context: ModelContext
    ) -> MovieLog {
        let log = MovieLog()
        if let uuid = UUID(uuidString: dto.id) { log.id = uuid }
        applyFields(dto, to: log)

        if let ext = dto.posterImageExt,
           let data = imageData["\(dto.id).\(ext)"] {
            log.moviePosterData = data
        }

        for ticketDTO in dto.ticketImages {
            guard let data = imageData["\(ticketDTO.id).\(ticketDTO.imageExt)"] else { continue }
            let ticket = TicketImage(imageData: data, movieLog: log)
            if let uuid = UUID(uuidString: ticketDTO.id) { ticket.id = uuid }
            ticket.createdAt = ticketDTO.createdAt
            ticket.ocrRawText = ticketDTO.ocrRawText
            context.insert(ticket)
            log.ticketImages.append(ticket)
        }

        for vdDTO in dto.viewingDates {
            let vd = ViewingDate(date: vdDTO.date)
            if let uuid = UUID(uuidString: vdDTO.id) { vd.id = uuid }
            context.insert(vd)
            log.viewingDates.append(vd)
        }

        return log
    }

    private static func updateLog(
        _ log: MovieLog,
        from dto: MovieLogDTO,
        imageData: [String: Data],
        context: ModelContext
    ) {
        applyFields(dto, to: log)

        if let ext = dto.posterImageExt,
           let data = imageData["\(dto.id).\(ext)"] {
            log.moviePosterData = data
        }

        // ticket images: UUID で upsert。backup にない既存 ticket は残す。
        for ticketDTO in dto.ticketImages {
            guard let ticketId = UUID(uuidString: ticketDTO.id) else { continue }
            if let existing = log.ticketImages.first(where: { $0.id == ticketId }) {
                if let data = imageData["\(ticketDTO.id).\(ticketDTO.imageExt)"] {
                    existing.imageData = data
                }
                existing.ocrRawText = ticketDTO.ocrRawText
                existing.createdAt = ticketDTO.createdAt
            } else {
                guard let data = imageData["\(ticketDTO.id).\(ticketDTO.imageExt)"] else { continue }
                let ticket = TicketImage(imageData: data, movieLog: log)
                ticket.id = ticketId
                ticket.createdAt = ticketDTO.createdAt
                ticket.ocrRawText = ticketDTO.ocrRawText
                context.insert(ticket)
                log.ticketImages.append(ticket)
            }
        }

        // viewing dates: UUID で upsert。backup にない既存 date は残す。
        for vdDTO in dto.viewingDates {
            guard let vdId = UUID(uuidString: vdDTO.id) else { continue }
            if let existing = log.viewingDates.first(where: { $0.id == vdId }) {
                existing.date = vdDTO.date
            } else {
                let vd = ViewingDate(date: vdDTO.date)
                vd.id = vdId
                context.insert(vd)
                log.viewingDates.append(vd)
            }
        }
    }

    private static func applyFields(_ dto: MovieLogDTO, to log: MovieLog) {
        log.watchedAt = dto.watchedAt
        log.movieTitle = dto.movieTitle
        log.theaterName = dto.theaterName
        log.review = dto.review
        log.screenNumber = dto.screenNumber
        log.seatNumber = dto.seatNumber
        log.screeningFormat = dto.screeningFormat
        log.admissionFee = dto.admissionFee
        log.viewingType = dto.viewingType
        log.streamingService = dto.streamingService
        log.tmdbId = dto.tmdbId
        log.movieOriginalTitle = dto.movieOriginalTitle
        log.movieReleaseYear = dto.movieReleaseYear
        log.movieSynopsis = dto.movieSynopsis
        log.movieSynopsisEn = dto.movieSynopsisEn
        log.watchedAtUnknown = dto.watchedAtUnknown
        log.watchedYearOnly = dto.watchedYearOnly
        log.theaterMemo = dto.theaterMemo
        log.rating = dto.rating
        log.createdAt = dto.createdAt
        log.updatedAt = dto.updatedAt
        log.movieRuntimeMinutes = dto.movieRuntimeMinutes
        log.movieGenresRaw = dto.movieGenresRaw
        log.movieDirector = dto.movieDirector
        log.movieCastRaw = dto.movieCastRaw
        log.metadataUpdatedAt = dto.metadataUpdatedAt
    }
}
