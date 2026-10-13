//
//  Archiver.swift
//  2026 New Relic
//

import Foundation

/// A uniquely named scratch directory in the user's caches folder, removed by `remove()`.
///
/// Each upload gets its own directory, so concurrent builds never share files.
final class TemporaryDirectory {
    let url: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) throws {
        guard let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw SymbolToolError.archiveFailed("could not locate the caches directory")
        }
        self.fileManager = fileManager
        url = caches.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func remove() {
        try? fileManager.removeItem(at: url)
    }
}

/// Zips directories using `NSFileCoordinator`'s `.forUploading` option (no external `zip` dependency).
struct Archiver {
    var fileManager: FileManager = .default

    /// Zips `directory` (the archive's root entry is the directory itself) and moves the archive to `destination`.
    func zip(_ directory: URL, to destination: URL) throws {
        var coordinationError: NSError?
        var moveError: Error?
        NSFileCoordinator().coordinate(readingItemAt: directory, options: .forUploading, error: &coordinationError) { zipURL in
            // `zipURL` is deleted when this block returns, so the archive must be moved out now.
            do {
                try fileManager.moveItem(at: zipURL, to: destination)
            } catch {
                moveError = error
            }
        }
        if let error = coordinationError ?? moveError {
            throw SymbolToolError.archiveFailed("could not zip \(directory.path): \(error)")
        }
    }

    func size(of url: URL) throws -> UInt64 {
        guard let size = try fileManager.attributesOfItem(atPath: url.path)[.size] as? UInt64 else {
            throw SymbolToolError.archiveFailed("could not read the size of \(url.path)")
        }
        return size
    }
}
