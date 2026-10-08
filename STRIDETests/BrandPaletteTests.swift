import Foundation
import Testing
import UIKit
@testable import STRIDE

struct BrandPaletteTests {
    // MARK: Contrast maths

    @Test func contrastRatioMatchesWCAGReferenceValues() {
        let black = BrandColor(hex: 0x000000)
        #expect(abs(BrandPalette.white.contrast(with: black) - 21) < 0.001)
        #expect(abs(BrandPalette.white.contrast(with: BrandPalette.white) - 1) < 0.001)
        // Symmetric.
        #expect(BrandPalette.ink.contrast(with: BrandPalette.white) == BrandPalette.white.contrast(with: BrandPalette.ink))
    }

    @Test func hexComponentsAreParsed() {
        let color = BrandColor(hex: 0xFE8726)
        #expect(abs(color.red - 254.0 / 255) < 1e-9)
        #expect(abs(color.green - 135.0 / 255) < 1e-9)
        #expect(abs(color.blue - 38.0 / 255) < 1e-9)
    }

    @Test func darkeningMovesTowardBlack() {
        let darker = BrandPalette.orange.darkened(by: 0.3)
        #expect(darker.luminance < BrandPalette.orange.luminance)
        #expect(BrandPalette.orange.darkened(by: 1).luminance == 0)
        #expect(BrandPalette.orange.darkened(by: 0) == BrandPalette.orange)
    }

    // MARK: Readability of the combinations the UI uses

    @Test func accentTextOnWhiteCardsIsReadable() {
        #expect(BrandPalette.ink.contrast(with: BrandPalette.white) >= 4.5)   // primary button text, filled button fill
    }

    @Test func accentOnDarkSurfacesIsReadable() {
        let darkSurface = BrandColor(hex: 0x1C1C1E)   // secondarySystemBackground in dark mode
        #expect(BrandPalette.inkOnDark.contrast(with: darkSurface) >= 4.5)
    }

    @Test func secondaryButtonTextIsReadableOnTheWholeGradient() {
        for stop in [BrandPalette.orange, BrandPalette.coral, BrandPalette.crimson] {
            let background = stop.darkened(by: BrandPalette.scrimOpacity)
            #expect(BrandPalette.white.contrast(with: background) >= 4.5, "white on scrim over \(stop)")
        }
    }

    @Test func largeWhiteTimerIsReadableFromTheMiddleOfTheGradient() {
        // The timer sits below the GPS card, past the light top-right corner. Large text needs 3:1.
        #expect(BrandPalette.white.contrast(with: BrandPalette.coral) >= 3)
        #expect(BrandPalette.white.contrast(with: BrandPalette.crimson) >= 3)
    }

    @Test func darkModeDimmingMakesWhiteTextReadableEverywhere() {
        for stop in [BrandPalette.orange, BrandPalette.coral, BrandPalette.crimson] {
            let dimmed = stop.darkened(by: BrandPalette.darkModeDimOpacity)
            #expect(BrandPalette.white.contrast(with: dimmed) >= 4.5, "white over dimmed \(stop)")
        }
    }

    @Test func gradientRunsFromLightToDark() {
        #expect(BrandPalette.orange.luminance > BrandPalette.coral.luminance)
        #expect(BrandPalette.coral.luminance > BrandPalette.crimson.luminance)
    }

    // MARK: Matches the icon

    /// The palette is not invented: each color is the icon's pixel. If the icon changes, this fails and
    /// the palette (and docs/DESIGN.md) must follow.
    @Test(.enabled(if: Self.iconPixels != nil, "icon file not reachable from the test process"))
    func paletteMatchesTheAppIcon() throws {
        let icon = try #require(Self.iconPixels)
        func pixel(_ x: Double, _ y: Double) -> BrandColor { icon.color(atFractionX: x, y: y) }

        func close(_ a: BrandColor, _ b: BrandColor, tolerance: Double = 4.0 / 255) -> Bool {
            abs(a.red - b.red) <= tolerance && abs(a.green - b.green) <= tolerance && abs(a.blue - b.blue) <= tolerance
        }
        #expect(close(pixel(0.977, 0.023), BrandPalette.orange))    // top-right corner
        #expect(close(pixel(0.023, 0.977), BrandPalette.crimson))   // bottom-left corner
        #expect(close(pixel(0.023, 0.023), BrandPalette.coral))     // top-left corner
        #expect(close(pixel(0.779, 0.181), BrandPalette.crimson))   // dot inside the end ring
    }

    // MARK: Icon sampling

    struct IconPixels {
        let width: Int
        let height: Int
        let data: [UInt8]   // RGBA

        func color(atFractionX x: Double, y: Double) -> BrandColor {
            let px = min(width - 1, Int(x * Double(width))), py = min(height - 1, Int(y * Double(height)))
            let offset = (py * width + px) * 4
            let hex = UInt32(data[offset]) << 16 | UInt32(data[offset + 1]) << 8 | UInt32(data[offset + 2])
            return BrandColor(hex: hex)
        }
    }

    /// Reads the icon from the source tree (the tests run on the Mac, which can see the repository).
    static let iconPixels: IconPixels? = {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("STRIDE/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
        guard let image = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return IconPixels(width: width, height: height, data: data)
    }()
}
