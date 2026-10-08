# STRIDE 1.0.0 — Release notes

First complete version of the MVP: record a run, keep it safe, and look at it
afterwards. It is distributed as source only: there is no App Store or TestFlight
build. See [DEMO](DEMO.md) to run it.

## Included

- **Live tracking** with start, pause, resume and finish, elapsed time, distance,
  current pace (20 s window) and average pace.
- **GPS filtering** with eight explicit rules (accuracy, stale fixes, impossible
  speed or jumps, duplicates, ordering) so noise never reaches the distance
  ([GPS_FILTERING](GPS_FILTERING.md)).
- **Background recording** with the `location` background mode, enabled only while
  a run is active and with the system indicator on ([BACKGROUND](BACKGROUND.md)).
- **Recovery**: every accepted point is saved as it arrives; an interrupted run
  is restored, as paused when more than 120 s passed, and a lost permission pauses
  the run ([RELIABILITY](RELIABILITY.md)).
- **History and route maps** on MapKit with start and finish markers
  ([HISTORY](HISTORY.md), [MAPS](MAPS.md)).
- **Interface** styled after the app icon: icon gradient, opaque cards and
  capsule buttons ([DESIGN](DESIGN.md)).
- **Local SwiftData storage**, no account and no backend ([DATA_MODEL](DATA_MODEL.md)).

## Quality

165 tests in 18 suites passed on 2026-10-08 in the iPhone 17 Pro simulator
(iOS 26.4): metrics, filtering, the run state machine, permission loss, recovery,
background configuration, deterministic noise scenarios and a seeded comparison of
CoreLocation configurations ([PERFORMANCE](PERFORMANCE.md)).

## Known limits

- **Not tested on a physical device.** Real GPS error, background suspension,
  kills by the OS and permission changes from Settings are unverified.
- **Battery not measured.** The device protocol in
  [PERFORMANCE](PERFORMANCE.md#manual-protocol-on-a-device--not-executed) has not
  been run; `Best` accuracy with a 5 m filter is a reasoned default.
- If the OS kills the app, STRIDE does not relaunch itself: the route has a gap
  until the user opens the app.
- The interface does not show a failed write to the store
  (`TrackingCoordinator.persistenceError` is kept but not displayed).
- No CI; tests are run locally. English-only interface; screenshots in light mode.
- Out of scope: social features, Apple Watch, HealthKit, heart-rate sensors,
  third-party integrations and any backend ([PRODUCT](PRODUCT.md)).

## Version

`MARKETING_VERSION` is `1.0.0` and `CURRENT_PROJECT_VERSION` stays `1`. The git
tag is `v1.0.0`. The version marks the end of the planned roadmap, not a store release.
