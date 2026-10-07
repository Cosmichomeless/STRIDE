# STRIDE — Background tracking

How a run keeps recording while the app is in the background or the screen is
locked, and what STRIDE deliberately does *not* do.

## Principle

STRIDE respects the iOS execution model. It does not play silent audio, schedule
fake background tasks or otherwise try to keep the process alive. A run keeps
recording because iOS keeps delivering location updates to an app that has
declared the `location` background mode and has an *active* location session.

## Configuration

| Piece | Value | Why |
|-------|-------|-----|
| `UIBackgroundModes` | `location` | Required for `allowsBackgroundLocationUpdates`. Declared in `project.yml` (`info:` key, XcodeGen generates `STRIDE/Info.plist`). |
| `allowsBackgroundLocationUpdates` | `true` only while a run is **active** | Background capability costs battery; it is off when idle, paused and finished. |
| `showsBackgroundLocationIndicator` | `true` | The blue status-bar pill tells the user the app is recording. It also keeps a When-In-Use app running in the background. |
| `pausesLocationUpdatesAutomatically` | `false` | The system must never silently stop a run because it guesses the user stopped moving. Pausing is the user's decision. |
| Authorization | When In Use is enough | With the indicator, a When-In-Use app can keep recording. Always is not requested. |

`LocationConfiguration.applyBackground(_:to:bundleInfo:)` only enables
background updates when the bundle declares `location` in `UIBackgroundModes`.
Setting `allowsBackgroundLocationUpdates = true` without the capability raises an
Objective-C exception, so a misconfigured build degrades to foreground-only
instead of crashing. A test asserts that the app bundle does declare the mode.

## Lifecycle

| Event | Behavior |
|-------|----------|
| `start` | Background tracking on, updates running. |
| `pause` | Background tracking off. |
| `resume` | Background tracking on, updates restarted. |
| `finish` | Background tracking off, updates stopped. |
| App → background, run **active** | Nothing changes: updates keep arriving. |
| App → background, idle / paused | GPS is released (`stopUpdates`) to save battery. |
| App → foreground | Updates restart (warm-up so Start has a fix ready). |
| App relaunched with an active run | The run is restored and background tracking is re-enabled. |

The scene phase is observed in `STRIDEApp` and forwarded to
`TrackingCoordinator.appDidEnterBackground()` / `appDidBecomeActive()`.

Every point received in the background goes through the same pipeline as in the
foreground (validator → metrics → `RunStore.append`), so each point is persisted
as it arrives and nothing depends on the UI being alive.

## If the process is killed

iOS may terminate a suspended or backgrounded app (memory pressure, user swipe).
Because points are persisted incrementally, the run is recovered on the next
launch with `restoreActiveRun()`. The time the app was not running produces a gap
in the route; the first point after the gap starts a new segment so no phantom
distance is added across it. STRIDE does not use significant-location-change or
region monitoring to relaunch itself, which is a known limitation.

## Verification status

Automated (deterministic, in the test suite):

- The location background mode is declared in the built bundle.
- Background updates are enabled only when declared, and the indicator follows.
- The coordinator enables/disables background tracking on start, pause, resume,
  finish and restore.
- Idle and paused runs release the GPS in the background; an active run keeps it.

**Not executed — requires a physical device.** The simulator does not suspend
apps or throttle location the way iOS does on hardware, so the following has not
been measured and no results are claimed:

1. Start a run outdoors, lock the screen, walk 10 minutes, unlock: the route has
   no holes and distance matches the foreground reference.
2. Switch to another app for 10 minutes mid-run: same check.
3. Start a run, force-quit the app, relaunch: the run is restored, the gap is
   a segment break.
4. Battery drain over 30 minutes with the screen locked (see PERFORMANCE.md).
