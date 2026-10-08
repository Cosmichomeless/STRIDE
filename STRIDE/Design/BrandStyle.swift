import SwiftUI

/// The icon's gradient, as a full-screen background. Dimmed in dark mode.
struct BrandBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        BrandPalette.gradient
            .overlay(Color.black.opacity(colorScheme == .dark ? BrandPalette.darkModeDimOpacity : 0))
            .ignoresSafeArea()
    }
}

/// A rounded shape with the soft shadow the icon puts under its route.
struct BrandCardShape: Shape {
    var cornerRadius: CGFloat = 20

    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
    }
}

extension View {
    /// Puts the screen on the brand gradient.
    func brandScreen() -> some View {
        background { BrandBackground() }
    }

    /// An opaque card, so text on it keeps the system's contrast in light and dark mode.
    func brandCard(cornerRadius: CGFloat = 20) -> some View {
        background {
            BrandCardShape(cornerRadius: cornerRadius)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        }
    }

    /// Frames a map like the icon frames the route: rounded, with a white edge and a soft shadow.
    func brandMapFrame(cornerRadius: CGFloat = 24) -> some View {
        clipShape(BrandCardShape(cornerRadius: cornerRadius))
            .overlay { BrandCardShape(cornerRadius: cornerRadius).stroke(.white, lineWidth: 3) }
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }
}

/// Full-width capsule buttons.
struct BrandButtonStyle: ButtonStyle {
    enum Kind {
        /// White capsule, like the icon's route. For the main action on the gradient.
        case primary
        /// Dark translucent capsule with white text. For the other actions on the gradient.
        case secondary
        /// Filled with the accent. For actions inside a white card.
        case filled
    }

    let kind: Kind
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(kind == .primary ? BrandPalette.ink.color : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background {
                Capsule()
                    .fill(fill)
                    .shadow(color: .black.opacity(kind == .secondary ? 0 : 0.2), radius: 8, y: 4)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
    }

    private var fill: Color {
        switch kind {
        case .primary: .white
        case .secondary: .black.opacity(BrandPalette.scrimOpacity)
        case .filled: BrandPalette.ink.color
        }
    }
}

extension ButtonStyle where Self == BrandButtonStyle {
    static var brandPrimary: BrandButtonStyle { .init(kind: .primary) }
    static var brandSecondary: BrandButtonStyle { .init(kind: .secondary) }
    static var brandFilled: BrandButtonStyle { .init(kind: .filled) }
}

/// The route endpoints of the icon: a white ring with a crimson dot.
struct RouteEndpointMarker: View {
    var size: CGFloat = 26

    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: size, height: size)
            .overlay { Circle().fill(BrandPalette.crimson.color).frame(width: size * 0.46) }
            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
    }
}

/// A small rounded square with the gradient and a white symbol, for list rows.
struct BrandBadge: View {
    let systemImage: String
    var size: CGFloat = 40

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(BrandPalette.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}
