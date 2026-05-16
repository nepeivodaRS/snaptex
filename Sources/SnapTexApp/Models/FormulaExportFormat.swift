import UniformTypeIdentifiers

enum FormulaExportFormat: CaseIterable, Identifiable {
    case png
    case eps

    var id: Self { self }

    var title: String {
        switch self {
        case .png:
            return "PNG"
        case .eps:
            return "EPS"
        }
    }

    var fileExtension: String {
        switch self {
        case .png:
            return "png"
        case .eps:
            return "eps"
        }
    }

    var contentType: UTType {
        switch self {
        case .png:
            return .png
        case .eps:
            return UTType(importedAs: "com.adobe.encapsulated-postscript")
        }
    }
}
