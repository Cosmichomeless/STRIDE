# STRIDE — Data model

SwiftData entities live in `STRIDE/Persistence/`.

## Run

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | unique |
| `startedAt` | `Date` | |
| `finishedAt` | `Date?` | set on finish |
| `statusRaw` / `status` | `RunStatus` | `active`, `paused`, `finished` (stored as raw string) |
| `accumulatedDuration` | `TimeInterval` | active time so far, **excluding** paused time. Final duration once finished. |
| `lastResumedAt` | `Date?` | start of the current active interval; `nil` when paused/finished |
| `distance` | `Double` | meters, from validated points |
| `averagePace` | `Double?` | seconds per km; `nil` until there is distance |

## LocationPoint

`id`, `runId`, `latitude`, `longitude`, `altitude`, `horizontalAccuracy`,
`speed`, `timestamp` (README fields) plus `startsSegment`.

`startsSegment` marks the first point after a pause or a recovery gap so
distance is never measured across it.

## Active-session state

There is no separate "session" table. A `Run` with status `active` or `paused`
**is** the persisted active session. `accumulatedDuration` + `lastResumedAt`
are enough to recompute the elapsed time after a relaunch:

```text
elapsed = accumulatedDuration + (now - lastResumedAt)   // when active
elapsed = accumulatedDuration                            // when paused / finished
```

At most one run may be in progress at a time (enforced by the store, issue #9).

## Plan for thousands of samples

- **No relationship** between `Run` and `LocationPoint`. A `to-many`
  relationship would make a fetched `Run` fault in its points, which hurts the
  history list. Points reference their run by `runId`.
- **Index** on `(runId, timestamp)` (`#Index`) so "points of run X in order" and
  "last point of run X" are index lookups.
- **Incremental writes**: points are inserted in small batches while tracking;
  existing rows are never rewritten.
- Run summary values (`distance`, `accumulatedDuration`, `averagePace`) are
  denormalized on `Run`, so the history list never touches points.
- Deleting a run deletes its points by `runId` (explicit, in the store).
- Typical volume: a 1 Hz stream is ~3,600 points/hour; a marathon is ~15,000.
  Tests cover 3,000 points per run.

## RunStore (implemented)

`Tracking/` talks to `RunStore` (`Persistence/RunStore.swift`) using plain values
(`RunRecord`, `TrackPoint`), never SwiftData types. `SwiftDataRunStore` is the
implementation; tests also run the same contract against an in-memory fake.

| Guarantee | How |
|-----------|-----|
| Run exists before it is tracked | `start` saves the run first; if that fails the run does not start. |
| Every transition is persisted | `pause`, `resume`, `finish` save the run (status, banked time, `lastResumedAt`). |
| Points are saved incrementally | Each accepted point is inserted (and the run distance updated) in one write. Rejected samples are never stored. |
| At most one run in progress | `save` throws `anotherRunInProgress` if another `active`/`paused` run exists. |
| Restore on launch | The coordinator reads `activeRun()`, replays its points into `RunMetrics` and rebuilds the session. |
| Gap after a kill | The first sample after relaunch starts a new segment: nothing is measured across the gap. |
| No permission on relaunch | An `active` run is restored as `paused`. |
| Completed runs survive restarts | They are plain rows, newest first via `completedRuns()`. |
| Write failures | Tracking continues in memory and `persistenceError` is set so the UI can warn that the run is not safe. |
