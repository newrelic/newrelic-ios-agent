//
//  SymbolUploadPipeline.swift
//  2026 New Relic
//

import Foundation

enum UploadOutcome: Equatable {
    case mapUploaded
    case oversizedMapReported
    case dsymUploaded
    case failed
    /// Failed in a way every other upload will too (rejected app token, unreachable server).
    case rejected
    /// Not attempted because an earlier upload was rejected.
    case skipped
}

/// Uploads symbols for one DWARF binary.
///
/// 1. Convert to New Relic map files, zip, and upload.
/// 2. If the zipped map exceeds the size threshold, send telemetry metadata instead.
/// 3. If conversion, zipping, or the map upload fails, upload the zipped dSYM — unless the failure
///    would affect the dSYM upload too (rejected app token, unreachable host).
struct SymbolUploadPipeline {
    let converter: MapFileConverter
    let uploader: SymbolUploading
    let logger: Logger
    var archiver = Archiver()
    var mapSizeThreshold: UInt64
    var uploadDsymsOnly = false

    @discardableResult
    func process(dwarfPath: String) -> UploadOutcome {
        if uploadDsymsOnly {
            logger.info("*** uploadDsymsOnly is set to true. Performing dSYM upload...")
            return uploadDSYM(dwarfPath)
        }

        do {
            return try uploadMap(for: dwarfPath)
        } catch let error as SymbolToolError where !error.shouldFallBackToDSYMUpload {
            logger.info("\(error) encountered processing dSYM at path: \(dwarfPath)")
            return .rejected
        } catch {
            logger.info("\(error) encountered processing dSYM at path: \(dwarfPath)")
            logger.info("Falling back to upload zipped dSYM...")
            return uploadDSYM(dwarfPath)
        }
    }

    func uploadMap(for dwarfPath: String) throws -> UploadOutcome {
        let maps = try converter.convert(dwarfPath: dwarfPath)

        let workspace = try TemporaryDirectory(fileManager: archiver.fileManager)
        defer { workspace.remove() }

        for map in maps {
            let fileURL = workspace.url.appendingPathComponent(map.fileName)
            do {
                try map.render().write(to: fileURL, atomically: false, encoding: .utf8)
            } catch {
                throw SymbolToolError.conversionFailed("could not write map file \(fileURL.path): \(error)")
            }
            logger.debug("Map file successfully saved to \(fileURL.path)")
        }

        let archive = workspace.url.appendingPathComponent("mapArchive.zip")
        try archiver.zip(workspace.url, to: archive)
        let size = try archiver.size(of: archive)
        logger.debug("Detected zipped map file size = \(size).")

        // Maps compress well, so only the zipped size is compared against the threshold.
        if size > mapSizeThreshold {
            logger.debug("Zipped map (\(size) bytes) exceeds 200MB threshold. Using telemetry fallback.")
            reportOversizedMap(archive, size: size)
            // The dSYM would be even larger, so there is never a dSYM fallback for oversized maps.
            return .oversizedMapReported
        }

        logger.debug("Uploading zipped map file (\(size) bytes)...")
        let response = try uploader.upload(archive, kind: .map, size: size)
        guard response.isCreated else {
            logger.info("*** Failed w/ error: \(response.statusText) when upload \(archive.path)")
            throw Self.error(for: response, uploading: "map")
        }
        logger.info("Successfully uploaded map: \(archive.path)")
        return .mapUploaded
    }

    func uploadDSYM(_ dwarfPath: String) -> UploadOutcome {
        do {
            let workspace = try TemporaryDirectory(fileManager: archiver.fileManager)
            defer { workspace.remove() }

            let dwarfURL = URL(fileURLWithPath: dwarfPath)
            try archiver.fileManager.copyItem(at: dwarfURL, to: workspace.url.appendingPathComponent(dwarfURL.lastPathComponent))

            let archive = workspace.url.appendingPathComponent("dsymArchive.zip")
            try archiver.zip(workspace.url, to: archive)
            logger.info("successfully zipped dSYM to \(archive.path)")

            let size = try archiver.size(of: archive)
            logger.debug("Detected zipped dSYM file size = \(size). Uploading...")

            let response = try uploader.upload(archive, kind: .dsym, size: size)
            guard response.isCreated else {
                logger.info("*** Failed w/ error: \(response.statusText) when upload dSYM: \(archive.path)")
                if response.isAuthenticationFailure {
                    logger.info(Self.authenticationHint)
                    return .rejected
                }
                return response.isUnreachable ? .rejected : .failed
            }
            logger.info("Successfully uploaded dSYM: \(archive.path)")
            return .dsymUploaded
        } catch {
            logger.info("\(error)")
            return .failed
        }
    }

    private func reportOversizedMap(_ archive: URL, size: UInt64) {
        do {
            let response = try uploader.sendOversizedMapTelemetry(size: size)
            if response.isOK {
                logger.info("Successfully sent telemetry for oversized map: \(archive.path)")
            } else {
                logger.info("*** Failed w/ error: \(response.statusText) sending telemetry for \(archive.path)")
            }
        } catch {
            logger.info("*** Failed sending telemetry for \(archive.path): \(error)")
        }
    }

    static let authenticationHint = "New Relic: The app token was rejected. Check the APP_TOKEN passed to run-symbol-tool in your Run Script build phase."

    private static func error(for response: UploadResponse, uploading what: String) -> SymbolToolError {
        let detail = "\(what) upload returned HTTP \(response.statusText) (curl exit status \(response.curlExitStatus))"
        if response.isAuthenticationFailure {
            return .uploadRejected("\(detail). \(authenticationHint) Skipping dSYM fallback.")
        }
        if response.isUnreachable {
            return .uploadRejected("\(detail). Could not reach the New Relic symbol upload server; check network access. Skipping dSYM fallback.")
        }
        return .uploadFailed(detail)
    }
}
