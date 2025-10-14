//
//  Data+md5Hex.swift
//  Agent
//
//  Created by Chris Dillard on 9/29/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import CommonCrypto
import Foundation

extension Data {
    /// Computes the MD5 hash of this data and returns it as a lowercase hexadecimal string.
    ///
    /// - Returns: A 32-character hexadecimal string representing the MD5 hash.
    ///
    /// - Note: MD5 is cryptographically broken and should not be used for security purposes.
    ///         This is suitable for checksums and non-security content identification only.
    func md5HexString() -> String {
        let digestLength = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: digestLength)

        _ = withUnsafeBytes { bytes in
            CC_MD5(bytes.baseAddress, CC_LONG(count), &digest)
        }

        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    /// Alternative computed property for convenience.
    var md5Hex: String {
        md5HexString()
    }
}
