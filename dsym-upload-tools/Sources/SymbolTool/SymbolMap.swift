//
//  SymbolMap.swift
//  2026 New Relic
//

import Foundation

/// One architecture slice of a DWARF binary, as reported by `symbols -uuid`.
struct DwarfSlice: Equatable {
    /// Lowercased, without dashes (e.g. `bdbb53df45803bb69123234b492d9f65`).
    let uuid: String
    let architecture: String
}

/// The New Relic map file for one architecture slice.
struct SymbolMap: Equatable {
    let slice: DwarfSlice
    var vmAddresses: [String] = []
    /// Padded hex address -> symbol name (functions, DWARF sections and source lines).
    var symbols: [String: String] = [:]

    var fileName: String { "\(slice.uuid).map" }

    /// Header lines, then sorted VM addresses, then symbols sorted by address.
    func render() -> String {
        var contents = ""
        contents.append("# uuid \(slice.uuid.uppercased())\n")
        contents.append("# architecture \(slice.architecture)\n")
        for vmAddress in vmAddresses.sorted() {
            contents.append("# vmaddr \(vmAddress)\n")
        }
        for address in symbols.keys.sorted() {
            if let name = symbols[address] {
                contents.append("\(address) \(name)\n")
            }
        }
        return contents
    }
}
