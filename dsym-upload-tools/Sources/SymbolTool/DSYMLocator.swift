//
//  DSYMLocator.swift
//  2026 New Relic
//

import Foundation

/// Finds the DWARF binaries inside every `.dSYM` bundle in `$DWARF_DSYM_FOLDER_PATH`.
struct DSYMLocator {
    struct Result: Equatable {
        /// Paths of the form `<folder>/<Name>.dSYM/Contents/Resources/DWARF/<binary>`, sorted.
        var dwarfBinaryPaths: [String] = []
        /// `.dSYM` bundles without a readable `Contents/Resources/DWARF` folder.
        var unreadableBundles: [String] = []
    }

    var fileManager: FileManager = .default

    /// Throws only if `folder` itself can't be read; one damaged bundle doesn't block the others.
    func locate(in folder: String) throws -> Result {
        var result = Result()
        for bundle in try fileManager.contentsOfDirectory(atPath: folder).sorted() where bundle.hasSuffix(".dSYM") {
            let dwarfFolder = "\(folder)/\(bundle)/Contents/Resources/DWARF"
            guard let binaries = try? fileManager.contentsOfDirectory(atPath: dwarfFolder) else {
                result.unreadableBundles.append("\(folder)/\(bundle)")
                continue
            }
            result.dwarfBinaryPaths += binaries.map { "\(dwarfFolder)/\($0)" }
        }
        result.dwarfBinaryPaths.sort()
        return result
    }
}
