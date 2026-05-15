import XCTest
@testable import SnapTexCore

final class OCRHistoryPolicyTests: XCTestCase {
    func testImageFingerprintIsStableForTheSameImageData() {
        let data = Data([0, 1, 2, 3, 4])

        XCTAssertEqual(OCRImageFingerprint.make(from: data), OCRImageFingerprint.make(from: data))
    }

    func testHistoryPolicyFindsExistingEntryForTheSameImageFingerprint() {
        let existing = ["first-image", "second-image"]

        XCTAssertEqual(1, OCRHistoryPolicy.replacementIndex(in: existing, for: "second-image"))
        XCTAssertNil(OCRHistoryPolicy.replacementIndex(in: existing, for: "third-image"))
    }
}
