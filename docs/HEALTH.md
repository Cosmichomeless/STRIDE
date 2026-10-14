# Apple Health

Finished runs are saved to Apple Health as running workouts ([#41](https://github.com/Cosmichomeless/STRIDE/issues/41)).

## What is written

- A running workout (outdoor) from the start of the run to the moment it was finished.
- The distance STRIDE measured (`distanceWalkingRunning`).
- The route, from the accepted GPS samples (`HKWorkoutRoute`). Altitude is not passed on: its accuracy is not recorded.
- Pause and resume events, so Health's duration matches the time actually run. Pauses are not stored on their own; they are the gaps between route segments (`WorkoutRecord.pauses`), which is accurate to a few seconds.

Runs with no distance are not written. Deleting a run in STRIDE does not delete it from Health.

## What is not

STRIDE **reads nothing** from Health: it asks only to share workouts, distance and routes, so the permission sheet uses `NSHealthUpdateUsageDescription`. The Info.plist also carries `NSHealthShareUsageDescription`, which says nothing is read: App Store Connect rejects an upload with the HealthKit entitlement and no such key, even though `read` is empty. Calories, heart rate, weight and age are not used.

## When the permission is asked

In context, never at launch:

1. The first time a run finishes with the setting on (it is on by default), or
2. when the user turns **Settings › Health › Save runs to Health** back on and the system has not been asked yet.

If the user declines, the run details say so and Settings offers *Open Settings*; the system never shows the sheet twice, so STRIDE does not ask again. Without access the app works exactly as before.

## Where the code is

| File | Role |
| --- | --- |
| `Health/HealthWriting.swift` | The boundary (`HealthAccess`, `HealthWriting`) |
| `Health/HealthKitWriter.swift` | The only file that imports HealthKit; also `StubHealthWriter` for UI tests (`-uitest-fake-health`) |
| `Health/WorkoutRecord.swift` | A finished run as plain values, with its pauses |
| `Health/HealthSync.swift` | When to ask, what to save, the outcome shown in the run details |

`AppSettings.saveToHealth` is the switch. The outcome of each run finished in the current launch is shown on its details screen, with *Try again* if saving failed.

## Setup and verification

- `project.yml` declares the `com.apple.developer.healthkit` entitlement. HealthKit also has to be enabled for the App ID in the Apple developer account (Xcode's automatic signing does it once a team is selected).
- Unit tests (`HealthTests`) cover the workout built from a run, when to ask, denial, failures, retry and no duplicates, using a double for Health.
- **Not verified:** writing to the real Health store, the permission sheet and the route in the Health app. That needs a signed build on a physical iPhone.
- Privacy manifest: HealthKit is not a required-reason API and the data never leaves the device, so `PrivacyInfo.xcprivacy` is unchanged (still no collected data); `PrivacyManifestTests` keeps checking that no data is collected, and `HealthTests` that the app declares only the write description.
