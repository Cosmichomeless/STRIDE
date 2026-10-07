# STRIDE — Reliability

What happens to a run when conditions go wrong, and the rule that keeps the state
consistent: **persisted state is the truth, and the app never invents time or
distance.** Nothing is resumed automatically after a problem.

## Scenarios

| Situation | Behavior |
|-----------|----------|
| Poor GPS (weak / lost fix) | Samples that fail the filter never reach the metrics or the route (see GPS_FILTERING.md). The timer keeps running; the status indicator shows `weak` / `lost`. After an outage the first plausible sample is accepted again by itself. |
| Screen lock / background | Updates keep arriving and are persisted point by point (see BACKGROUND.md). |
| Location access revoked **during** a run | The run is paused at that moment (`PauseReason.permissionLost`), persisted, and a banner explains it; the denied state offers **Open Settings**. When access returns the run stays paused. Resume is disabled (and ignored in the coordinator) until access is available. |
| Process killed, relaunched within 120 s | The run is restored and stays active; the first new sample starts a new segment. |
| Process killed, relaunched after more than 120 s | The run is restored **paused where the activity stopped** (`PauseReason.interrupted(at:)`): the last stored point, or the last resume if there is none. The time the app was not running is not counted. The user resumes (new segment) or finishes. |
| Relaunch with an active run and no permission | Paused with `permissionLost`. |
| Finish while paused by a problem | Allowed: the run is saved with what was recorded. |

## Decisions

- **Interruption threshold, 120 s** (`TrackingCoordinator.interruptionThreshold`).
  Short restarts (a crash, an OS relaunch) should not interrupt a run in progress;
  minutes of silence mean the app really was not recording. Time in a gap shorter
  than the threshold is counted as running time, while its distance is not (a new
  segment starts): a documented trade-off.
- **No automatic resume.** Resuming after losing access or after a long gap could
  silently add distance or time; the user's decision keeps the data honest.
- **No data is discarded.** An interrupted run is kept and can be finished, never
  deleted automatically.
- `pauseReason` lives in memory: it explains an event of this session. The paused
  state itself is persisted.

## Verification status

Deterministic tests in `TrackingCoordinatorTests` cover: permission loss during a
run (pause, no auto-resume, blocked resume, new segment after resuming), finishing
while paused, long and short relaunch gaps, a gap with no points, relaunch without
permission and cleanup of the reason.

Not verified on a physical device: real permission revocation from Settings while
the app is in the background, real kills by the OS and tunnels/urban canyons.
