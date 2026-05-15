import XCTest
@testable import SnapTexCore

final class PredictionSanitizerTests: XCTestCase {
    func testSanitizerFixesTokenizerFractionArtifactsFromScreenshot() {
        let prediction = #"\lambda - 3 / _ { 2 } + \lambda - 1 / _ { 2 }"#

        XCTAssertEqual(
            #"\lambda - \frac{3}{2} + \lambda - \frac{1}{2}"#,
            LaTeXPredictionSanitizer.sanitize(prediction)
        )
    }

    func testSanitizerCompactsTokenizerSpacingIntoReadableLatex() {
        let prediction = #"\rho ( r , \theta , \phi ) = \frac { \rho _ { 0 } } { 1 + \exp [ ( r - R ( \theta , \phi ) ) / a ] } ."#

        XCTAssertEqual(
            #"\rho(r, \theta, \phi) = \frac{\rho_{0}}{1 + \exp[(r - R(\theta, \phi))/a]}."#,
            LaTeXPredictionSanitizer.sanitize(prediction)
        )
    }

    func testSanitizerCompactsSingleLetterRunsInsideMathTextCommands() {
        let prediction = #"\ R ( \theta , \phi ) = R _ { 0 } ^ { \mathrm { e f f } } ( \beta , \gamma )"#

        XCTAssertEqual(
            #"\ R(\theta, \phi) = R_{0}^{\mathrm{eff}}(\beta, \gamma)"#,
            LaTeXPredictionSanitizer.sanitize(prediction)
        )
    }

    func testSanitizerPreservesWordSpacesInsideTextCommands() {
        let prediction = #"\text { total energy } = E"#

        XCTAssertEqual(
            #"\text{total energy} = E"#,
            LaTeXPredictionSanitizer.sanitize(prediction)
        )
    }

    func testSanitizerRemovesMarkdownFencesAndMathDelimiters() {
        let prediction = """
        ```latex
        \\[ x^2 + y^2 \\]
        ```
        """

        XCTAssertEqual("x^2 + y^2", LaTeXPredictionSanitizer.sanitize(prediction))
    }
}
