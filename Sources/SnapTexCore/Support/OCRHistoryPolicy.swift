import CryptoKit
import Foundation

public enum OCRImageFingerprint {
    public static func make(from data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

public enum OCRHistoryPolicy {
    public static func replacementIndex(in fingerprints: [String], for fingerprint: String) -> Int? {
        fingerprints.firstIndex(of: fingerprint)
    }
}
