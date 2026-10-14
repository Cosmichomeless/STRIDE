import Foundation
import Testing
@testable import STRIDE

/// App Review rejects builds whose privacy manifest is missing a required-reason API the app uses.
struct PrivacyManifestTests {
    private func manifest() throws -> [String: Any] {
        let url = try #require(Bundle(for: AppSettings.self).url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    @Test func appDoesNotTrackOrCollectData() throws {
        let manifest = try manifest()
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
    }

    /// `AppSettings` keeps the user's choices in `UserDefaults`, so the manifest must say why.
    @Test func userDefaultsAccessIsDeclared() throws {
        let types = try #require(try manifest()["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let entry = types.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" }
        #expect(entry?["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
    }

    @Test func policyAndSupportLinksAreSecureURLs() {
        for url in [AppLinks.privacyPolicy, AppLinks.support] {
            #expect(url.scheme == "https")
        }
    }
}
