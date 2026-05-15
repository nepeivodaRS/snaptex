import XCTest
@testable import SnapTexCore

final class OutputFormattingTests: XCTestCase {
    func testOutputFormatsApplyExpectedWrappers() {
        XCTAssertEqual("x + y", LaTeXOutputFormat.raw.apply(to: " x + y "))
        XCTAssertEqual("$x + y$", LaTeXOutputFormat.inlineMath.apply(to: "x + y"))
        XCTAssertEqual("$$x + y$$", LaTeXOutputFormat.displayMath.apply(to: "x + y"))
        XCTAssertEqual("\\begin{equation}\nx + y\n\\end{equation}", LaTeXOutputFormat.equation.apply(to: "x + y"))
    }

    func testOutputFormatTitlesUseVisibleDelimiters() {
        XCTAssertEqual(["Raw", "$", "$$", "Equation"], LaTeXOutputFormat.allCases.map(\.title))
    }

    func testMathBodyRemovesEquationEnvironment() {
        let body = LaTeXSource.mathBody(from: "\\begin{equation}\nx + y\n\\end{equation}")

        XCTAssertEqual("x + y", body)
    }

    func testValidatorRejectsUnknownLegacyFontCommand() {
        let issue = LaTeXValidator.firstIssue(in: #"\sl x + y"#)

        XCTAssertEqual("Unsupported or unknown command \\sl.", issue?.message)
    }
}
