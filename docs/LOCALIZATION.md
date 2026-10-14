# Localization

STRIDE is available in English (source), Spanish, French, German, Italian and Brazilian Portuguese.

## How it works

- `STRIDE/Localizable.xcstrings` holds every text of the UI; the English text is the key.
- `STRIDE/InfoPlist.xcstrings` holds the permission prompts (`NSLocationWhenInUseUsageDescription`, `NSHealthUpdateUsageDescription`). The English text also stays in `project.yml` as the fallback.
- Views use `Text("…")`, `Button("…")` and so on, which look the key up. Texts built outside a view are `LocalizedStringResource` (`GPSStatus.label`, `LocationAuthorization.message`, `PauseReason.message`, `DistanceUnit.name`, …) so they follow the language too.
- Beware of a ternary of literals passed where a `String` is accepted (`.navigationTitle(a ? "x" : "y")`): it becomes a plain `String` and is **not** localized. Type it as `LocalizedStringKey` or wrap it in `Text`.
- Numbers, dates, durations and the spoken values (VoiceOver) come from `Locale`, so `1,25 km` in Spanish and `1.25 km` in English need no extra strings. Miles are the default in the United States and the United Kingdom (see `DistanceUnit.default(for:)`).
- The unit symbols (`km`, `mi`) and the clock format (`28:10`) are the same in every language.

## Adding or changing a text

1. Add the key to `Localizable.xcstrings` with all six languages (Xcode shows the catalog as a table), or edit the existing one.
2. Keep the format arguments (`%@`, `%lld`) of the key in every translation: `LocalizationTests` fails if a language is missing, is not `translated`, or changes them.

## Adding a language

Add it to both catalogs, add it to `LocalizationTests.languages`, run `xcodegen generate` (the project picks the region up from the catalogs) and check the longest screens at the largest accessibility text size, as `LocalizationUITests` does for German.

## Tests

- `LocalizationTests` (unit): every key in both catalogs is translated into every language with matching format arguments, the app bundle ships every language, texts resolve per language and the permission prompt is translated.
- `LocalizationUITests`: Spanish shows the translated tabs and controls; German at the largest accessibility size passes the accessibility audit. One finding is ignored on purpose (a settings footnote that the audit reports as possibly clipped while all of it is visible); see the comment in the test.
- `ScreenshotWalkthroughTests` and `SettingsUITests` pin English, so their labels do not depend on the simulator.
