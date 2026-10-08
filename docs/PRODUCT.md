# STRIDE — Product definition

This document defines the running MVP, the user flows and the screens. It is the
reference for the implementation issues that follow.

## MVP scope

A user can record a run outdoors, see live stats, leave the app (background or
locked screen) without losing data, and review past runs on a map.

In scope: location permissions, GPS status, start / pause / resume / finish,
GPS point collection, distance, duration, current and average pace, background
tracking, route visualization, run persistence, history and run details.

Out of scope: see [Out of scope](#out-of-scope) below.

## Screens

| Screen | Purpose |
|--------|---------|
| **Tracking** (home) | Start a run and, once started, show live stats, live map and controls. |
| **History** | List of completed runs, newest first. |
| **Run details** | Route on a map plus summary stats of one completed run. |

Navigation is a `TabView` with two tabs (Tracking, History). Run details is
pushed from History. An active run always wins: if a run is active on launch the
app opens on the Tracking tab.

## Run lifecycle

```text
          start            pause
 idle ───────────▶ active ───────▶ paused
                     ▲  ◀───────    │
                     │    resume    │
                     │              │
                     └── finish ────┴──▶ finished
```

`finished` is terminal. A run that is `active` or `paused` is persisted and is
restored after the app is killed (see ARCHITECTURE.md).

## Flows

### Start

1. The user taps **Start** on the Tracking screen.
2. If location permission is `notDetermined`, the system prompt is shown first;
   the run starts only after permission is granted.
3. If permission is granted but there is no usable GPS fix yet, the run still
   starts, the timer runs, and the screen shows "Acquiring GPS…". Distance only
   accumulates once validated points arrive.
4. The run is persisted as the active session immediately.

### Pause

1. The user taps **Pause**.
2. The timer stops, locations are no longer recorded and the pace shows `--`.
3. The paused state is persisted.

### Resume

1. The user taps **Resume**.
2. The timer continues from the elapsed time. The first point after resuming is
   not connected to the last point before pausing (no phantom distance
   accumulated while paused).

### Finish

1. The user taps **Finish** (confirmation dialog: "Finish run?").
2. The run is closed with `finishedAt`, final duration, distance and average
   pace, then persisted as completed.
3. The user lands on the Run details screen of that run.

Finishing with no recorded distance discards nothing automatically; the run is
saved as a run with 0 m, so the user is never surprised by data loss.

### History

1. Completed runs are listed newest first with date, distance, duration and
   average pace.
2. Swipe to delete a run (with its location points).
3. Empty state: "No runs yet — go for a run".

### Run details

1. Shows the full route as a polyline, framed automatically to fit the route.
2. Shows distance, duration, average pace, start and finish time.

## Live stats on the Tracking screen

- Elapsed time (excludes paused time)
- Distance
- Current pace (rolling window over the last validated points)
- Average pace (total moving time / total distance)
- GPS status indicator

## GPS status

| Status | Meaning | Indicator |
|--------|---------|-----------|
| `acquiring` | Authorized but no valid fix yet | Orange, "Acquiring GPS…" |
| `good` | Recent fix with good horizontal accuracy | Green |
| `weak` | Recent fix but poor accuracy | Orange, "Weak GPS signal" |
| `lost` | No valid fix for several seconds during a run | Red, "GPS signal lost" |
| `unavailable` | Location services off or permission denied | Red, see below |

## Location permission denied or restricted

STRIDE cannot record a run without location. The experience must be explicit and
never silently broken:

| Authorization | Tracking screen |
|---------------|-----------------|
| `notDetermined` | Start button asks for permission. |
| `denied` | Start disabled. Message: "Location access is off. STRIDE needs it to record your route." Button **Open Settings** opens the app's settings page. |
| `restricted` | Start disabled. Message: "Location is restricted on this device." No settings button (the user cannot change it). |
| `authorizedWhenInUse` | Start enabled. A hint explains that background tracking needs the app to stay in use; a run in progress continues in the background using the blue status bar indicator. |
| `authorizedAlways` | Start enabled. |

If permission is revoked **during** a run:

1. The run is paused automatically and persisted.
2. A banner explains why and offers **Open Settings**.
3. When access is granted again the user can resume manually (never auto
   resumes, so no unexpected distance is added).

History and Run details work without location permission.

## Out of scope

The first version does not include:

- Social network, followers, leaderboards or challenges
- Training plans or AI coaching
- Apple Watch, HealthKit or heart-rate sensors
- Strava integration
- Backend services

## Purpose

STRIDE is not primarily a fitness product. It is a mobile systems project built
around reliable native location tracking, background execution, GPS processing,
persistence and lifecycle management. It does not try to compete with products
such as Strava or Nike Run Club; a focused running experience is the vehicle to
explore how a real iOS app interacts with location services and the operating
system in the foreground, in the background and with the screen locked.
