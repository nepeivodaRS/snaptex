import XCTest
@testable import SnapTexCore

final class WorkerProtocolTests: XCTestCase {
    func testRecognitionModeTitlesExposeNumericOCRPasses() {
        XCTAssertEqual("1", RecognitionMode.fast.title)
        XCTAssertEqual("2", RecognitionMode.balanced.title)
        XCTAssertEqual("3", RecognitionMode.accurate.title)
        XCTAssertEqual(1, RecognitionMode.fast.passCount)
        XCTAssertEqual(2, RecognitionMode.balanced.passCount)
        XCTAssertEqual(3, RecognitionMode.accurate.passCount)
    }

    func testWorkerRequestEncodesImagePathModeAndModel() throws {
        let request = UniMERWorkerRequest(
            imagePath: "/tmp/formula.png",
            mode: .accurate,
            model: .small,
            validateRender: true,
            logVerbosity: .debug
        )

        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual("/tmp/formula.png", json["image_path"] as? String)
        XCTAssertEqual("accurate", json["mode"] as? String)
        XCTAssertEqual("small", json["model"] as? String)
        XCTAssertEqual(true, json["validate_render"] as? Bool)
        XCTAssertEqual("debug", json["log_verbosity"] as? String)
    }

    func testWorkerResponseDecodesPredictionAndAlternatives() throws {
        let data = Data(#"{"ok":true,"prediction":"x^2","alternatives":["x^2","x^{2}"],"model":"small","mode":"balanced"}"#.utf8)

        let response = try JSONDecoder().decode(UniMERWorkerResponse.self, from: data)

        XCTAssertTrue(response.ok)
        XCTAssertEqual("x^2", response.prediction)
        XCTAssertEqual(["x^2", "x^{2}"], response.alternatives)
        XCTAssertEqual(.small, response.model)
        XCTAssertEqual(.balanced, response.mode)
    }
}
