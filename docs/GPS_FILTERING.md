# STRIDE — GPS filtering

Raw GPS data is not trusted. Every `LocationSample` goes through `SampleFilter`
(`STRIDE/Tracking/SampleFilter.swift`) before it can be persisted or measured.
Only *accepted* samples become `LocationPoint`s and count towards distance.

## Rules

Checked in this order; the first failing rule rejects the sample.

| # | Reason | Rule | Default | Why |
|---|--------|------|---------|-----|
| 1 | `invalidAccuracy` | `horizontalAccuracy < 0` | — | CoreLocation's way of saying the coordinate is invalid. |
| 2 | `lowAccuracy` | `horizontalAccuracy > maxHorizontalAccuracy` | **30 m** | Beyond ~30 m the error is larger than 5 s of running; it adds more noise than signal. Urban canyons commonly report 50–100 m. |
| 3 | `beforeSegmentStart` | `timestamp < segment start` | run start | Right after Start, CoreLocation may deliver the last cached fix from before the run. |
| 4 | `stale` | `now - timestamp > maxSampleAge` | **10 s** | Late/cached fixes describe where the user *was*. |
| 5 | `impossibleReportedSpeed` | `speed > maxSpeed` | **12 m/s** | The device-reported speed is impossible for running. Negative speed means "unknown" and is ignored. |
| 6 | `outOfOrder` | `timestamp <= previous.timestamp` | — | Non-increasing time makes speed meaningless. |
| 7 | `duplicate` | distance to previous `< minDistance` | **1 m** | Standing still produces jitter that would accumulate fake distance. |
| 8 | `impossibleJump` | `distance / dt > maxSpeed` | **12 m/s** | The "Point C, 450 m away" case from the README. |

`maxSpeed = 12 m/s` is 43 km/h (a 100 m world-record sprint is ~12.4 m/s), so no
real runner is rejected while car-speed GPS glitches are.

### The reference sample

Rules 6–8 compare with the **last accepted** sample, not the last received one.
That is what makes rejection self-healing:

```text
A ── B (8 m) ── C (450 m, rejected) ── D (near B, accepted)
                     │
                     └─ the reference stays B, so D is measured against B
```

Because `dt` is measured from the last *accepted* sample, a real displacement
after a GPS outage (tunnel) grows `dt` until the implied speed is plausible and
the new position is accepted. A single bad point never poisons the track.

### Segments

A pause, a recovery after the app was killed, or the start of a run begins a new
*segment* (`SampleValidator.beginSegment`). The first accepted sample of a segment
has no `previous`, so no distance is measured from the position before the gap.
It is persisted with `startsSegment = true`.

## Trade-offs

- **Stricter accuracy** (e.g. 20 m) gives a cleaner path but leaves holes in
  poor-signal areas; **looser** (e.g. 50 m) keeps continuity but adds zig-zag.
  30 m is a middle ground; the value is a parameter and is exercised in the
  performance notes.
- A fixed speed ceiling is simple and explainable; it cannot catch a slow drift
  (e.g. 5 m/s while standing). That is handled partially by `minDistance` and
  accuracy, and accepted as a limitation.
- Rejected samples are dropped, not smoothed. A Kalman/smoothing step could
  reduce zig-zag further but is out of scope for the MVP.

## Diagnostics

`SampleValidator.rejections` counts rejected samples per reason, so a run's
quality can be inspected without storing rejected points.

## Tests

`SampleFilterTests` uses deterministic sequences built from a known speed
(no CoreLocation involved): every rule, the exact boundary of each threshold,
the README noise scenario, recovery after a jump and segment starts.
