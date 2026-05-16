import XCTest
@testable import SnapTexApp

final class ScreenshotServiceTests: XCTestCase {
    func testMissingCaptureOutputIsTreatedAsCancelledCapture() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("snaptex-missing-\(UUID().uuidString)")
            .appendingPathExtension("png")

        XCTAssertNil(try ScreenshotService.validatedCaptureOutput(at: url))
    }
}
