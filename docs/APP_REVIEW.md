# App Review — notes and compliance checklist

What App Review needs for STRIDE 1.0, and what is still open. The text in
[Review notes](#review-notes-paste-into-app-store-connect) is meant to be pasted as is.

## Review notes (paste into App Store Connect)

> STRIDE records outdoor runs. It has **no accounts and no sign-in**, so no demo account is needed.
>
> **Why `UIBackgroundModes: location`.** A run lasts 30–90 minutes and the user locks the screen or
> uses other apps meanwhile. Without background location, recording stops and the route and distance
> are lost. Location is requested *When In Use* only, and updates run **only while a run is being
> recorded**: they start on **Start** and stop on **Finish**, or when location access is withdrawn.
> The blue location indicator is shown while recording. Location is never used when no run is active
> and is never sent off the device.
>
> **How to see it.** Allow location *While Using the App*, tap **Start** on the Tracking tab, lock the
> screen and walk or drive for a minute (in the Simulator: Features › Location › City Run), unlock
> and check that distance and the route kept growing. Tap **Finish**, then open the History tab.
>
> **Health.** STRIDE can save a finished run to Apple Health (**write only**: workout, distance and
> route). It never reads Health data, so there is no `NSHealthShareUsageDescription`. The permission
> sheet appears the first time a run finishes, or when the user turns **Settings › Health › Save runs
> to Health** back on; the switch is on by default and the app works the same without Health access.
>
> **Data.** Runs are stored only on the device. No analytics, advertising, tracking or third-party SDKs.
> Privacy policy: <https://cosmichomeless.github.io/STRIDE/privacy/>

## Checklist

| Item | State |
| --- | --- |
| `PrivacyInfo.xcprivacy`: no tracking, no collected data, `UserDefaults` reason `CA92.1` | Done (checked by `PrivacyManifestTests`) |
| Privacy policy (EN/ES) and support page | Written: `docs/privacy.md`, `docs/support.md` |
| Policy and support linked inside the app (Settings › About) | Done |
| Policy and support URL in App Store Connect | **Open.** Needs App Store Connect |
| GitHub Pages serves the policy and support at `https://cosmichomeless.github.io/STRIDE/privacy/` and `/support/` | Pages enabled from `main` › `/docs`; the app links point there. **Open:** check both URLs load once the PRs are merged, then use them in App Store Connect |
| HealthKit: `com.apple.developer.healthkit` entitlement and `NSHealthUpdateUsageDescription` (no Share key: nothing is read) | Done in `project.yml`. HealthKit is enabled for the App ID and the app runs on a real iPhone |
| Health writing checked on a real iPhone (permission sheet, workout and route in the Health app) | Workout saved and visible in Health on a real iPhone; the logic is also covered by unit tests with a double. Check the route in the workout's map before submitting |
| Review notes above | Written; paste in App Store Connect |
| Video of background recording with the screen locked | **Open.** Needs a physical iPhone and an outdoor run ([#40](https://github.com/Cosmichomeless/STRIDE/issues/40)) |
| Privacy "nutrition labels": *Data Not Collected* | **Open.** Needs App Store Connect. HealthKit ([#41](https://github.com/Cosmichomeless/STRIDE/issues/41)) writes to Apple Health on the device and sends nothing to the developer, so *Data Not Collected* remains true |
| Age rating questionnaire | **Open.** Needs App Store Connect. Expected 4+: no objectionable content, no web access, no user-generated content |
| EU trader status (DSA) | **Open.** A decision for the account holder (trader or not) in App Store Connect |

## Why "Data Not Collected"

Apple counts data as *collected* only when it leaves the device. STRIDE keeps location, routes and
runs in the app's own storage and sends them nowhere, so nothing is collected. Apple Maps tiles are
requested by MapKit under Apple's own policy, which the privacy policy states.
