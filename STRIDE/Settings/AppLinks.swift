import Foundation

/// Where the privacy policy and support live. They point at the repository until a GitHub Pages
/// site replaces them (see docs/APP_REVIEW.md); change them here and in App Store Connect together.
enum AppLinks {
    static let privacyPolicy = URL(string: "https://github.com/Cosmichomeless/STRIDE/blob/main/docs/privacy.md")!
    static let support = URL(string: "https://github.com/Cosmichomeless/STRIDE/blob/main/docs/support.md")!
}
