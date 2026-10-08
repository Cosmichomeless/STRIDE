# STRIDE — Location and background architecture

How a GPS fix travels from CoreLocation to a saved run, which thresholds decide
whether it is trusted, what iOS allows while the app is in the background, how a
run is recovered, and which trade-offs were accepted. This page ties the others
together; the detail lives in [GPS_FILTERING](GPS_FILTERING.md),
[BACKGROUND](BACKGROUND.md), [RELIABILITY](RELIABILITY.md) and
[PERFORMANCE](PERFORMANCE.md), which remain the source of truth for their numbers.

## End to end

```text
CLLocationManager ─▶ LocationService ─▶ TrackingCoordinator ─▶ SampleValidator ─▶ RunStore ─▶ RunMetrics ─▶ UI
  (CoreLocation)     AsyncStream of      state machine +        SampleFilter        SwiftData   from stored   renders
                     LocationSample      permission/recovery    rules               (disk)      points
```

| Step | Type | What it does |
|------|------|--------------|
| 1 | `LocationConfiguration` | The only place with CoreLocation knobs: `Best` accuracy, 5 m `distanceFilter`, `.fitness`, no automatic pausing. |
| 2 | `LocationService` | Owns `CLLocationManager` and authorization, and turns each `CLLocation` into a plain `LocationSample` on an `AsyncStream` (buffering the newest 256). |
| 3 | `TrackingCoordinator` | Created by the app, not by a view. Ignores samples unless the run is active, drives pause/resume/finish and reacts to permission changes and relaunches. |
| 4 | `SampleValidator` / `SampleFilter` | Stateless rules plus the last accepted sample of the current segment. A sample that fails never reaches the distance or the route. |
| 5 | `RunStore` | Every accepted point and every state change is written before it counts. |
| 6 | `RunMetrics` | Distance and pace computed from the accepted points. |

## Filtering thresholds

Rules run in this order and the first one that fails decides the rejection.
Values are the defaults of `SampleFilter`; why each was chosen is in
[GPS_FILTERING](GPS_FILTERING.md).

| # | Rule | Rejects when | Threshold |
|---|------|--------------|-----------|
| 1 | `invalidAccuracy` | horizontal accuracy is negative (CoreLocation's "no fix") | `< 0` |
| 2 | `lowAccuracy` | uncertainty radius too large | `> 30 m` |
| 3 | `beforeSegmentStart` | timestamp is before the start of the current segment | segment start |
| 4 | `stale` | the fix is too old on arrival | `> 10 s` |
| 5 | `impossibleReportedSpeed` | speed reported by CoreLocation is not human | `> 12 m/s` |
| 6 | `outOfOrder` | not newer than the last accepted sample | `dt <= 0` |
| 7 | `duplicate` | same position as the last accepted sample | `< 1 m` |
| 8 | `impossibleJump` | the implied speed since the last accepted sample is not human | `> 12 m/s` |

Two properties matter more than the numbers:

- **The reference is the last accepted sample, not the last received one.** While
  samples are rejected the elapsed time keeps growing, so a real displacement
  (tunnel, GPS outage) becomes plausible again by itself instead of poisoning every
  later sample.
- **A segment starts after a pause or a recovery gap.** The first sample of a new
  segment has no previous point, so nothing is connected across the gap.

Metrics use their own thresholds on the accepted points: current pace is measured
over a 20 s window and needs at least 5 s and 5 m inside it, it disappears when
the last sample is older than 10 s, and average pace needs 10 m of distance
([METRICS](METRICS.md)). Separately, the GPS status shown in the UI is `good` up
to 20 m of accuracy and `lost` after 10 s without a fix (`GPSStatusEvaluator`).

## Background restrictions

iOS suspends a normal app shortly after it leaves the foreground. STRIDE keeps
recording only through the mechanism the system provides for this, and only while
it is needed:

| Rule | Implementation |
|------|----------------|
| The capability is declared | `UIBackgroundModes: [location]` in `project.yml`. |
| Background updates are on only while a run is active | `setBackgroundTracking(true)` on start and resume, `false` on pause and finish. |
| Setting it without the capability would crash | `LocationConfiguration.applyBackground` checks the bundle for `location` first, so it is safe in tests and previews. |
| The user is told | `showsBackgroundLocationIndicator = true` shows the system blue indicator. |
| The system must not stop a run on its own | `pausesLocationUpdatesAutomatically = false`. |
| Leaving the app releases the GPS unless a run is active | `appDidEnterBackground()` stops updates when the state is idle, paused or finished (battery); `appDidBecomeActive()` warms it up again so Start has a fix. |
| Authorization is When-In-Use | `requestWhenInUseAuthorization()`; there is no Always request. |

What STRIDE deliberately does **not** do: play silent audio, schedule background
tasks to stay alive, or use significant-location-change or region monitoring to
relaunch itself.

## Recovery

The persisted store is the source of truth, so recovery is a rebuild from disk
(`restoreActiveRun`), not a restore of in-memory state.

| Situation | Behavior |
|-----------|----------|
| Relaunch with a run active and recent activity (within `interruptionThreshold` = 120 s) | The run is restored as active and updates restart. The time without samples is a gap: the first new sample starts a segment, so no distance is added. |
| Relaunch with a run active and the last activity more than 120 s ago | The app was not running. The run is paused **at the last activity** (`PauseReason.interrupted(at:)`) instead of counting the silence as running time; the user resumes or finishes. |
| Relaunch with a run that was paused | Restored as paused. |
| Permission lost during an active run | The run is paused with `PauseReason.permissionLost`. It never resumes by itself, and `resume()` does nothing until access is back. |
| Permission lost while the app was closed, recent activity | Detected on restore: the active run is paused with `permissionLost` instead of restarting updates. If the activity is older than 120 s, the interrupted pause above applies first. |
| Permission granted after pressing Start | The pending start continues (`isAwaitingPermission`). |
| A write to the store fails | The error is kept in `TrackingCoordinator.persistenceError`; the run in memory continues. The interface does not show this error yet, so a failing disk would go unnoticed by the user. |

## Trade-offs

| Decision | Gained | Cost |
|----------|--------|------|
| Reject samples instead of smoothing them | Distance comes only from points that passed explicit, testable rules. | A genuinely fast or imprecise stretch is dropped; the route can show gaps. |
| Reference the last accepted sample | The filter heals itself after an outage. | After a long rejection streak, a first accepted point can be a long way from the last one. |
| `Best` accuracy with a 5 m filter | A usable route without one update per second. | Highest radio cost of the options; 10 m is the next candidate to measure ([PERFORMANCE](PERFORMANCE.md)). |
| Background updates only during an active run | Respects the iOS model and saves battery when idle or paused. | Nothing is recorded while a run is paused, by design. |
| When-In-Use, no Always | A smaller permission request. | If iOS kills the app, it cannot relaunch it; the gap lasts until the user opens it. |
| 120 s interruption threshold | Short interruptions (a tunnel, a quick relaunch) do not interrupt the run. | A fixed cut-off: a 3-minute kill is paused, a 100-second one is not. |
| Persist each accepted point | An interrupted run loses at most the last point. | One write per accepted sample. |
| Gaps add no distance | The metrics never invent a straight line across missing data. | Real distance covered during a gap is not counted. |

## What is verified and what is not

- **Verified with automated tests** (simulator, injected clock): every filter rule
  and its boundaries, rule precedence, a pipeline fed with hundreds of bad samples
  that yields the exact distance, pause/resume cycles, recovery on both sides of
  the 120 s threshold, permission loss and the background configuration guard.
- **Simulated, not measured:** the effect of `desiredAccuracy` and
  `distanceFilter` on distance error and update count, using a model of
  CoreLocation ([PERFORMANCE](PERFORMANCE.md)).
- **Not verified on a physical device:** real GPS error, how long iOS keeps the
  app alive in the background, behavior when the system kills it, permission
  changes from Settings, and battery. The thresholds above are reasoned values,
  not values calibrated outdoors.
