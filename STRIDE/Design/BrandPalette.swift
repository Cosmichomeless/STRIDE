import SwiftUI

/// An sRGB color with the WCAG maths needed to check text contrast in tests.
struct BrandColor: Equatable, Sendable {
    /// Components in 0...1.
    let red: Double
    let green: Double
    let blue: Double

    init(hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    private init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    var color: Color { Color(red: red, green: green, blue: blue) }

    /// WCAG relative luminance.
    var luminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio, from 1 (identical) to 21 (black on white).
    func contrast(with other: BrandColor) -> Double {
        let (high, low) = (max(luminance, other.luminance), min(luminance, other.luminance))
        return (high + 0.05) / (low + 0.05)
    }

    /// This color under a black layer of the given opacity.
    func darkened(by opacity: Double) -> BrandColor {
        BrandColor(red: red * (1 - opacity), green: green * (1 - opacity), blue: blue * (1 - opacity))
    }
}

/// The colors of the app icon (`AppIcon.appiconset/icon-1024.png`), sampled from it, plus the
/// derived values the UI uses. See docs/DESIGN.md.
enum BrandPalette {
    // MARK: Sampled from the icon

    /// Top-right corner of the icon.
    static let orange = BrandColor(hex: 0xFE8726)
    /// Middle of the diagonal (top-left and bottom-right corners average to this).
    static let coral = BrandColor(hex: 0xF66534)
    /// Bottom-left corner of the icon; also the dot inside the route endpoints.
    static let crimson = BrandColor(hex: 0xE82A4D)

    // MARK: Derived

    static let white = BrandColor(hex: 0xFFFFFF)
    /// Deeper crimson for text and fills on white: 5.3:1 against white, where `crimson` has 4.3:1.
    static let ink = BrandColor(hex: 0xD01F47)
    /// Light accent for text and icons on dark surfaces.
    static let inkOnDark = BrandColor(hex: 0xFF7A90)

    /// Black layer behind secondary controls, so white text on them reaches 4.5:1 on the whole gradient.
    static let scrimOpacity = 0.30
    /// Black layer over the gradient in dark mode.
    static let darkModeDimOpacity = 0.30

    /// App tint: `ink` on light surfaces, `inkOnDark` on dark ones.
    static let accent = Color(uiColor: UIColor { traits in
        let accent = traits.userInterfaceStyle == .dark ? inkOnDark : ink
        return UIColor(red: accent.red, green: accent.green, blue: accent.blue, alpha: 1)
    })

    /// Selected tab: the tab bar floats over the gradient on a glass pill that is light in light mode,
    /// where `ink` is too pale, so it takes a deep crimson there and `inkOnDark` in dark mode.
    static let tabTint = Color(uiColor: UIColor { traits in
        let tint = traits.userInterfaceStyle == .dark ? inkOnDark : BrandColor(hex: 0x7A0F2B)
        return UIColor(red: tint.red, green: tint.green, blue: tint.blue, alpha: 1)
    })

    /// The icon's diagonal gradient, light corner top-right.
    static let gradient = LinearGradient(
        colors: [orange.color, coral.color, crimson.color],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
}
