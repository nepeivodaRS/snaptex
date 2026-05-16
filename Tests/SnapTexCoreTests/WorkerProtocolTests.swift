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
            model: OCRModelSelection(provider: .uniMERNet, size: .medium),
            validateRender: true,
            logVerbosity: .debug
        )

        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let model = try XCTUnwrap(json["model"] as? [String: Any])

        XCTAssertEqual("/tmp/formula.png", json["image_path"] as? String)
        XCTAssertEqual("accurate", json["mode"] as? String)
        XCTAssertEqual("unimernet", model["provider"] as? String)
        XCTAssertEqual("m", model["size"] as? String)
        XCTAssertEqual(true, json["validate_render"] as? Bool)
        XCTAssertEqual("debug", json["log_verbosity"] as? String)
    }

    func testWorkerRequestEncodesPaddlePaddleLargeModelSelection() throws {
        let request = UniMERWorkerRequest(
            imagePath: "/tmp/formula.png",
            mode: .balanced,
            model: OCRModelSelection(provider: .paddlePaddle, size: .large),
            validateRender: true
        )

        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let model = try XCTUnwrap(json["model"] as? [String: Any])

        XCTAssertEqual("paddlepaddle", model["provider"] as? String)
        XCTAssertEqual("l", model["size"] as? String)
    }

    func testWorkerResponseDecodesPredictionAndAlternatives() throws {
        let data = Data(#"{"ok":true,"prediction":"x^2","alternatives":["x^2","x^{2}"],"model":{"provider":"unimernet","size":"m"},"mode":"balanced"}"#.utf8)

        let response = try JSONDecoder().decode(UniMERWorkerResponse.self, from: data)

        XCTAssertTrue(response.ok)
        XCTAssertEqual("x^2", response.prediction)
        XCTAssertEqual(["x^2", "x^{2}"], response.alternatives)
        XCTAssertEqual(OCRModelSelection(provider: .uniMERNet, size: .medium), response.model)
        XCTAssertEqual(.balanced, response.mode)
    }

    func testWorkerResponseDecodesLegacyStringModel() throws {
        let data = Data(#"{"ok":true,"prediction":"x^2","model":"base","mode":"fast"}"#.utf8)

        let response = try JSONDecoder().decode(UniMERWorkerResponse.self, from: data)

        XCTAssertEqual(OCRModelSelection(provider: .uniMERNet, size: .large), response.model)
    }
}
