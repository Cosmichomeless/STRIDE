# Distance and pace

All numbers come from **validated** samples (see [GPS_FILTERING.md](GPS_FILTERING.md));
rejected samples never reach `RunMetrics`.

## Distance

Sum of the haversine distance between consecutive accepted samples of the same
segment. A sample that starts a segment (first sample, first after resume, first
after a recovery gap) adds nothing, so there is no phantom distance across a pause.

## Average pace

`active time / distance` in seconds per kilometer. Paused time is excluded because
the session timer excludes it.

- Unknown (`--`) below 10 m of total distance, or with no elapsed time.

## Current pace

`window duration / window distance` over the last 20 s of the **current segment**.

| Situation | Result |
|-----------|--------|
| Fewer than 2 samples in the window | `--` |
| Window covers < 5 s | `--` |
| Window covers < 5 m (standing still, jitter) | `--` |
| Last sample older than 10 s (sparse GPS, tunnel) | `--`, never extrapolated |
| Session paused | `--` |
| New segment | window resets |

Anything slower than 60 min/km is displayed as `--` (`PaceFormat`).

## Sparse GPS

If samples stop arriving and then resume with a plausible displacement, the filter
accepts the next sample and the distance is the straight line between them. This
under-counts corners taken during the outage; the alternative (interpolating) would
invent data. Documented trade-off.

## Rebuilding after a relaunch

`RunMetrics` is incremental and deterministic. Replaying the persisted points in
order, with their `startsSegment` flag, yields the same totals as the live run.
