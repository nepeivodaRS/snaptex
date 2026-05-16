import AppKit
import XCTest
@testable import SnapTexApp

final class MenuBarIconTests: XCTestCase {
    func testMenuBarIconUsesGeneratedFramedFunctionImage() throws {
        let source = try sourceFile("Sources/SnapTexApp/App/SnapTexApp.swift")

        XCTAssertTrue(source.contains("Image(nsImage: MenuBarIconImage.make())"))
        XCTAssertFalse(source.contains("Image(systemName: \"viewfinder\")"))
        XCTAssertFalse(source.contains("Text(\"f(x)\")"))
    }

    func testGeneratedMenuBarIconIsTemplateAndWideEnoughForFunctionText() {
        let icon = MenuBarIconImage.make()

        XCTAssertTrue(icon.isTemplate)
        XCTAssertEqual(NSSize(width: 26, height: 18), icon.size)
    }

    private func sourceFile(_ path: String) throws -> String {
        try String(
            contentsOf: try Self.sourceRoot().appendingPathComponent(path),
            encoding: .utf8
        )
    }

    private static func sourceRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
