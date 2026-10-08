# STRIDE — Running the demo

There is no recorded video, no public build and no TestFlight: the demo is run
locally in the iOS Simulator. This page describes what to do and what each step
shows. The final screens are in [`screenshots/`](screenshots/README.md).

## Prepare

```bash
brew install xcodegen
xcodegen generate
open STRIDE.xcodeproj   # run the STRIDE scheme on an iPhone simulator
```

Allow location **While Using the App** when asked.

## 1. Active tracking

1. On the **Tracking** tab wait for the GPS status to leave "acquiring".
2. Tap **Start**. Elapsed time starts; distance and pace appear once there is movement.
3. In another terminal, drive a route (a short loop in the Retiro park, Madrid):

   ```bash
   xcrun simctl location booted start --speed=3 --interval=1 \
     40.4153,-3.6844 40.4160,-3.6830 40.4172,-3.6838 40.4164,-3.6855 40.4153,-3.6844
   ```

   You can also use Xcode's **Debug → Simulate Location** or the simulator's
   **Features → Location**. Stop it with `xcrun simctl location booted clear`.
4. Watch distance, current pace and average pace update and the route grow on the map.
5. Try **Pause** and **Resume**: time and distance stop while paused.

Shown in [`02-tracking-active.png`](screenshots/02-tracking-active.png).

## 2. Finish, map and history

1. Tap **Finish**. The run is saved.
2. Open the **History** tab: the run is listed with distance, duration and pace
   ([`04-history.png`](screenshots/04-history.png)).
3. Open it: the route is drawn on a MapKit map with start and finish markers
   ([`03-run-details.png`](screenshots/03-run-details.png)).

## 3. Recovery

1. Start a run and let it record for a few seconds.
2. Kill the app without finishing: swipe it away in the app switcher, or
   `xcrun simctl terminate booted com.cosmichomeless.stride`.
3. Relaunch it. Within 120 s of the last activity the run is restored as active;
   after more than 120 s it is restored as **paused** at the last activity, and you
   can resume or finish it. The time the app was not running adds no distance.
4. To see the permission case, revoke location in the simulator's Settings during a
   run: the run pauses and does not resume until access is back.

## What has and has not been checked

- Tracking, history and the map are exercised by the screenshot walkthrough
  (`STRIDEScreenshots` scheme), which drives a synthetic run through the real UI.
- **Recovery has no screenshot and no automated UI test.** Its rules (the 120 s
  threshold, restoring as paused, permission loss, no distance across a gap) are
  covered by unit tests with an injected clock; the manual steps above are the
  procedure, not a recorded result. See
  [LOCATION_ARCHITECTURE](LOCATION_ARCHITECTURE.md#recovery).
- Nothing here was run on a physical device. Background recording with the screen
  locked is verified by configuration tests, not by an outdoor run.
