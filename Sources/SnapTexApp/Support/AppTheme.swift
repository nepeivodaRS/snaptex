import SwiftUI

enum AppTheme {
    static let windowBackground = Color(red: 0.067, green: 0.075, blue: 0.090)
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
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundStyle(AppTheme.primaryForeground.opacity(isEnabled ? 1 : 0.45))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(AppTheme.primaryButtonBackground.opacity(isEnabled ? configuration.isPressed ? 0.78 : 1 : 0.42))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct GraphiteSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary.opacity(isEnabled ? 1 : 0.38))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(AppTheme.controlBackground.opacity(isEnabled ? configuration.isPressed ? 0.72 : 1 : 0.42))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius)
                    .strokeBorder(AppTheme.border, lineWidth: 1)
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
}
