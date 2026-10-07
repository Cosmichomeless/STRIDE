# STRIDE — Architecture

This document defines the module boundaries and who owns which responsibility.
The guiding rule from the README: **the UI is not the source of truth for an
active run — persistent domain state is.**

## Pipeline

```text
CoreLocation ──▶ LocationService ──▶ SampleFilter ──▶ TrackingSession ──▶ RunStore ──▶ RunMetrics ──▶ SwiftUI
 (system)         (Location/)         (Tracking/)       (Tracking/)       (Persistence/) (Calculations/) (Features/)
```

Data flows one way. Each stage only knows the stage before it through a small
protocol or a plain value type, so each one can be tested with deterministic
input and no device.

## Module ownership

| Module | Owns | Does **not** own |
|--------|------|------------------|
| `Location/` | `CLLocationManager`, authorization, GPS status, background-update configuration, converting `CLLocation` into `LocationSample`, exposing an `AsyncStream`. | Whether a sample is good, whether a run is active. |
| `Tracking/` | The run state machine (idle / active / paused / finished), the timer (active duration without paused time), the GPS sample filter, and the `TrackingCoordinator` that wires location → filter → session → store. | Persistence details, UI. |
| `Calculations/` | Pure functions: distance, current pace, average pace, formatting inputs. Operate on validated samples only. | Filtering, state. |
| `Persistence/` | SwiftData models/containers, saving runs and points incrementally, restoring the active run, deleting runs. | Business rules (state transitions). |
| `Models/` | Plain `Sendable` value types shared across modules (`LocationSample`, run status, GPS status). | Behavior. |
| `Maps/` | MapKit view wrappers, polyline building, map framing. | Data loading. |
| `Features/*` | SwiftUI views and their view models. Render state, forward user intents. | Any state that must survive a view being destroyed. |

## Where the active run lives

```text
┌───────────────────────────────┐
│ STRIDEApp (@main)             │  creates once, owns for the process lifetime
│  ├─ ModelContainer (SwiftData)│
│  └─ TrackingCoordinator       │  @MainActor @Observable
│       ├─ LocationService      │
│       ├─ TrackingSession      │
│       └─ RunStore             │
└───────────────┬───────────────┘
                │ environment
        ┌───────▼────────┐
        │ SwiftUI views  │  read state, call intents (start/pause/resume/finish)
        └────────────────┘
```

- The `TrackingCoordinator` is created by the `App`, not by a view. Navigating
  away, switching tabs or recreating a view does not affect the run.
- Every transition and every accepted sample is written to the `RunStore`
  **before** it is considered part of the run. If the process is killed, the
  store is the truth.
- On launch the coordinator asks the store for an active/paused run and, if it
  exists, restores the session from it (see "Recovery").

## Session state machine

```text
idle ──start──▶ active ──pause──▶ paused ──resume──▶ active
                  │                  │
                  └──────finish──────┴──────▶ finished
```

Invalid transitions (for example `resume` while `active`) are rejected by the
session with an error and do not change state. The state machine takes the
clock as a dependency so tests are deterministic.

## Time

Active duration is accumulated from the intervals during which the session is
`active`. Paused time is never counted. The session stores `startedAt`, the
accumulated active duration and, while active, the timestamp of the last
resume, so the duration is recomputable after a relaunch.

## Filtering and calculations

- Raw `LocationSample`s enter the filter. The filter returns *accepted* or
  *rejected(reason)* using the previously accepted sample as reference.
- Only accepted samples are persisted as `LocationPoint`s and used by
  `Calculations/`. Rejected samples are dropped (counted for diagnostics).
- Calculations are pure and stateless; they take a sequence of accepted samples
  and return distance/pace.

## Persistence boundaries

- `Persistence/` exposes a `RunStore` protocol to `Tracking/`. The SwiftData
  implementation is an implementation detail; tests use an in-memory store.
- Points are appended in small batches (not rewritten) to cope with thousands of
  samples per run.
- `Run` aggregate values (distance, duration, average pace) are stored on
  finish; while running they are derived.

## Concurrency

- Swift Concurrency throughout. `LocationService` exposes
  `AsyncStream<LocationSample>`; the coordinator consumes it in a single
  `Task`, which makes processing order deterministic.
- UI-facing types are `@MainActor`. Pure value types are `Sendable`.
- No GCD or timers in domain logic; the clock is injected.

## Background behavior

STRIDE uses the supported iOS mechanism for background location: the
`location` background mode with `allowsBackgroundLocationUpdates` while a run is
active. It does not use silent audio or other process keep-alive tricks. See
`docs/BACKGROUND.md` (added with the background tracking work).

## Recovery

```text
launch ─▶ RunStore.activeRun()
              ├─ none           ─▶ idle
              └─ active/paused  ─▶ restore session
                                    ├─ paused ─▶ stay paused
                                    └─ active ─▶ was killed while running:
                                                 mark gap, resume location updates
                                                 if authorized, else pause
```

Time between the last persisted sample and the relaunch is treated as a gap:
no distance is invented across it (the first sample after a gap does not connect
to the last one).
