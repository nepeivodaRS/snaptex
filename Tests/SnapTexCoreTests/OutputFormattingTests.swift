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

    func testValidatorRejectsUnexpectedTopLevelLineBreakCommand() throws {
        let latex = #"d^{5}x = (\beta^{4}\ {}d beta\\))\times(\operatorname{sin}3\gamma d\gamma d\Omega)"#
        let badRange = try XCTUnwrap(latex.range(of: #"\\"#))

        let issue = LaTeXValidator.firstIssue(in: latex)

        XCTAssertEqual("Unexpected line break command \\\\.", issue?.message)
        XCTAssertEqual(latex.distance(from: latex.startIndex, to: badRange.lowerBound), issue?.location)
        XCTAssertEqual(2, issue?.length)
    }

    func testValidatorAllowsLineBreakInsideMatrixEnvironment() {
        let issue = LaTeXValidator.firstIssue(in: #"\begin{matrix}a&b\\c&d\end{matrix}"#)

        XCTAssertNil(issue)
    }
}
