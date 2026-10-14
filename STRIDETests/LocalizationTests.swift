import Foundation
import Testing
@testable import STRIDE

/// Every user-visible text exists in each supported language, and the language is really in the app.
struct LocalizationTests {
    static let languages = ["es", "fr", "de", "it", "pt-BR"]

    private struct Catalog: Decodable {
        struct Entry: Decodable {
            struct Localization: Decodable {
                struct StringUnit: Decodable { let state: String; let value: String }
                let stringUnit: StringUnit?
            }
            let localizations: [String: Localization]?
        }
        let sourceLanguage: String
        let strings: [String: Entry]
    }

    private static func catalog(_ name: String) throws -> Catalog {
        // .../STRIDETests/LocalizationTests.swift -> .../STRIDE/<name>.xcstrings
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("STRIDE/\(name).xcstrings")
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    }

    /// `%@`, `%lld`, `%d`… in order: translations may reword but must keep the same arguments.
    private static func specifiers(_ text: String) -> [String] {
        text.matches(of: /%(?:\d+\$)?(?:lld|ld|d|@|f)/).map { String($0.output).replacing(/\d+\$/, with: "") }
    }

    @Test(arguments: ["Localizable", "InfoPlist"])
    func everyKeyIsTranslatedIntoEveryLanguage(table: String) throws {
        let catalog = try Self.catalog(table)
        #expect(catalog.sourceLanguage == "en")
        #expect(!catalog.strings.isEmpty)
        for (key, entry) in catalog.strings {
            for language in Self.languages {
                let unit = entry.localizations?[language]?.stringUnit
                #expect(unit?.state == "translated", "\(table): '\(key)' is not translated into \(language)")
                #expect(unit?.value.isEmpty == false, "\(table): '\(key)' is empty in \(language)")
                if let unit {
                    #expect(
                        Self.specifiers(unit.value) == Self.specifiers(key),
                        "\(table): '\(key)' changes its format arguments in \(language)"
                    )
                }
            }
        }
    }

    @Test func theAppShipsEverySupportedLanguage() {
        let shipped = Set(Bundle(for: TrackingCoordinator.self).localizations)
        for language in ["en"] + Self.languages {
            #expect(shipped.contains(language), "\(language) is missing from the app bundle")
        }
    }

    private static func localized(_ resource: LocalizedStringResource, _ language: String) -> String {
        var resource = resource
        resource.locale = Locale(identifier: language)
        return String(localized: resource)
    }

    @Test func buttonTextsFollowTheLanguage() {
        #expect(Self.localized("Resume", "en") == "Resume")
        #expect(Self.localized("Resume", "es") == "Reanudar")
        #expect(Self.localized("Resume", "de") == "Fortsetzen")
        #expect(Self.localized("Resume", "pt-BR") == "Retomar")
    }

    @Test func modelTextsAreTranslated() {
        var resources: [LocalizedStringResource] = [
            GPSStatus.acquiring.label, GPSStatus.good.label, GPSStatus.weak.label,
            GPSStatus.lost.label, GPSStatus.unavailable.label,
            PauseReason.permissionLost.message, PauseReason.interrupted(at: .now).message,
            DistanceUnit.kilometers.name, DistanceUnit.miles.name,
        ]
        resources += [LocationAuthorization.denied, .restricted, .whenInUse].compactMap(\.message)
        for resource in resources {
            let english = Self.localized(resource, "en")
            for language in Self.languages {
                let translated = Self.localized(resource, language)
                // A few short words are the same word (e.g. "GPS ready" differs, "Pause" does not), so only the
                // long messages must differ; every text must at least resolve to something.
                #expect(!translated.isEmpty)
                if english.count > 24 { #expect(translated != english, "'\(english)' is not translated into \(language)") }
            }
        }
    }

    @Test func spokenPaceUsesTheLanguageOfTheLocale() {
        let es = Locale(identifier: "es_ES")
        #expect(SpokenFormat.pace(nil, unit: .kilometers, locale: es) == "No disponible")
        #expect(SpokenFormat.pace(325, unit: .kilometers, locale: es).hasSuffix("por kilómetro"))
        #expect(SpokenFormat.pace(325, unit: .miles, locale: Locale(identifier: "de_DE")).hasSuffix("pro Meile"))
    }

    @Test func numbersFollowTheRegion() {
        #expect(DistanceFormat.distance(1_250, unit: .kilometers, locale: Locale(identifier: "es_ES")) == "1,25")
        #expect(DistanceFormat.distance(1_250, unit: .kilometers, locale: Locale(identifier: "fr_FR")) == "1,25")
        #expect(DistanceFormat.distance(1_250, unit: .kilometers, locale: en) == "1.25")
    }

    @Test func thePermissionPromptIsTranslated() throws {
        let bundle = Bundle(for: TrackingCoordinator.self)
        for language in Self.languages {
            let path = try #require(bundle.path(forResource: language, ofType: "lproj"), "no \(language).lproj")
            let text = try #require(Bundle(path: path)).localizedString(
                forKey: "NSLocationWhenInUseUsageDescription", value: "MISSING", table: "InfoPlist"
            )
            #expect(text != "MISSING" && !text.hasPrefix("STRIDE uses your location"), "\(language): \(text)")
        }
    }
}
