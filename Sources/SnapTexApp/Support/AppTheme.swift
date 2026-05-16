import AppKit
import SwiftUI

enum AppTheme {
    static let windowBackground = Color(red: 0.067, green: 0.075, blue: 0.090)
    static let windowBackgroundNSColor = NSColor(
        calibratedRed: 0.067,
        green: 0.075,
        blue: 0.090,
        alpha: 1
    )
    static let panelBackground = Color(red: 0.090, green: 0.102, blue: 0.122)
    static let raisedPanelBackground = Color(red: 0.110, green: 0.125, blue: 0.149)
    static let insetBackground = Color(red: 0.055, green: 0.063, blue: 0.075)
    static let controlBackground = Color(red: 0.102, green: 0.114, blue: 0.137)
    static let border = Color.white.opacity(0.085)
    static let selectedBorder = Color.white.opacity(0.20)
    static let selectedBackground = Color.white.opacity(0.075)
    static let primaryButtonBackground = Color(red: 0.920, green: 0.930, blue: 0.945)
    static let primaryForeground = Color(red: 0.067, green: 0.075, blue: 0.090)
    static let quietText = Color.white.opacity(0.58)

    static let panelCornerRadius: CGFloat = 8
    static let controlCornerRadius: CGFloat = 7
}

struct GraphitePanelModifier: ViewModifier {
    var background: Color = AppTheme.panelBackground
    var border: Color = AppTheme.border
    var radius: CGFloat = AppTheme.panelCornerRadius

    func body(content: Content) -> some View {
        content
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(border, lineWidth: 1)
            }
    }
}

struct GraphitePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GraphiteButtonBody(configuration: configuration, kind: .primary)
    }
}

struct GraphiteSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GraphiteButtonBody(configuration: configuration, kind: .secondary)
    }
}

struct GraphiteTextInputModifier: ViewModifier {
    let width: CGFloat
    var background: Color = AppTheme.controlBackground

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .controlSize(.small)
            .padding(.horizontal, 7)
            .frame(width: width, height: 24)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            }
    }
}

private enum GraphiteButtonKind {
    case primary
    case secondary
}

private struct GraphiteButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let kind: GraphiteButtonKind

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .fontWeight(kind == .primary ? .semibold : .regular)
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .primary ? 12 : 11)
            .padding(.vertical, kind == .primary ? 7 : 6)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius)
                    .strokeBorder(border, lineWidth: 1)
            }
            .shadow(
                color: shadowColor,
                radius: isHovered && isEnabled && !configuration.isPressed ? 7 : 0,
                y: isHovered && isEnabled && !configuration.isPressed ? 1 : 0
            )
            .scaleEffect(configuration.isPressed ? 0.97 : isHovered && isEnabled ? 1.02 : 1)
            .offset(y: isHovered && isEnabled && !configuration.isPressed ? -1 : 0)
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius))
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var foreground: Color {
        switch kind {
        case .primary:
            return AppTheme.primaryForeground.opacity(isEnabled ? 1 : 0.45)
        case .secondary:
            return .primary.opacity(isEnabled ? 1 : 0.38)
        }
    }

    private var background: Color {
        switch kind {
        case .primary:
            let opacity: Double
            if !isEnabled {
                opacity = 0.42
            } else if configuration.isPressed {
                opacity = 0.78
            } else {
                opacity = isHovered ? 0.94 : 1
            }
            return AppTheme.primaryButtonBackground.opacity(opacity)
        case .secondary:
            let opacity: Double
            if !isEnabled {
                opacity = 0.42
            } else if configuration.isPressed {
                opacity = 0.78
            } else {
                opacity = isHovered ? 1 : 0.92
            }
            return AppTheme.controlBackground.opacity(opacity)
        }
    }

    private var border: Color {
        switch kind {
        case .primary:
            return Color.white.opacity(isHovered && isEnabled ? 0.22 : 0.14)
        case .secondary:
            return isHovered && isEnabled ? AppTheme.selectedBorder : AppTheme.border
        }
    }

    private var shadowColor: Color {
        switch kind {
        case .primary:
            return AppTheme.primaryButtonBackground.opacity(0.16)
        case .secondary:
            return Color.black.opacity(0.18)
        }
    }
}

extension View {
    func graphitePanel(
        background: Color = AppTheme.panelBackground,
        border: Color = AppTheme.border,
        radius: CGFloat = AppTheme.panelCornerRadius
    ) -> some View {
        modifier(GraphitePanelModifier(background: background, border: border, radius: radius))
    }

    func graphiteTextInput(
        width: CGFloat,
        background: Color = AppTheme.controlBackground
    ) -> some View {
        modifier(GraphiteTextInputModifier(width: width, background: background))
    }
}
