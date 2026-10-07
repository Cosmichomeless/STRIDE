# STRIDE — Accuracy, update frequency and battery

How the CoreLocation configuration trades route accuracy against update
frequency, which configuration STRIDE uses and why, and — just as important —
what has **not** been measured.

```text
Accuracy ↔ Update Frequency ↔ Battery Usage
```

## Chosen configuration

`LocationConfiguration.default`:

| Setting | Value | Role |
|---------|-------|------|
| `desiredAccuracy` | `kCLLocationAccuracyBest` | Drives which radios CoreLocation keeps on. This is the dominant battery cost, and the accuracy a running route needs. |
| `distanceFilter` | `5` m | Drops updates for movement under 5 m. At running speed (~3 m/s) this is about one update every 1.7 s instead of one per second. |
| `activityType` | `.fitness` | Lets the system tune its filtering for pedestrian motion. |
| `pausesLocationUpdatesAutomatically` | `false` | Never silently stops a run (see BACKGROUND.md). |

It is kept as is. The simulation below shows that a larger filter lowers the
distance inflation caused by GPS noise and halves the number of updates each
time it doubles, but it also starts cutting corners, and the model cannot tell
what that is worth in battery. **10 m is the first candidate to try on a
device**; it should replace 5 m only if the battery gain measured there justifies
the coarser route.

## What the simulation is

`STRIDETests/Support/RunSimulator.swift` replays a known path (3 km, at 3 m/s)
through a model of CoreLocation and then through the **real**
`SampleValidator` and `RunMetrics`, so the validation thresholds and the distance
calculation are the production ones. Everything is seeded (SplitMix64), so
results are reproducible; tables below are the mean of 30 seeds.

Model of CoreLocation:

- An update is delivered when the true movement since the last delivered one
  reaches `distanceFilter`, and never faster than once per second.
- Position error is Gaussian per axis with a σ that depends on
  `desiredAccuracy`: **5 m** (Best), **10 m** (NearestTenMeters), **50 m**
  (anything coarser). `horizontalAccuracy` is reported as 1.5σ.
- The error is correlated in time (AR(1)), as real GPS error drifts instead of
  being white noise.

Two routes: a **straight** road, where noise can only add distance, and a
**winding** one (±25 m switchbacks, 150 m wavelength, 3 702 m long), where
sparse sampling cuts corners.

## Results

Error is `(measured − true) / true`. "Delivered" is the number of updates the
location layer sends (a proxy for wake-ups and database writes, not a battery
figure). "Accepted" is how many passed validation.

### Noise correlation 0.97 per second (middle case)

| Configuration | Straight error | Winding error | Delivered (straight) | Accepted (straight) |
|---------------|---------------:|--------------:|---------------------:|--------------------:|
| Best / no filter | +8.60 % | +8.63 % | 1001 | 979 |
| **Best / 5 m (current)** | **+4.11 %** | **+3.92 %** | **501** | **500** |
| Best / 10 m | +1.95 % | +1.65 % | 251 | 251 |
| Best / 20 m | +0.46 % | −0.10 % | 143 | 143 |
| 10 m / 10 m | +8.30 % | +8.21 % | 251 | 250 |
| 100 m / 50 m | 0 m measured | 0 m measured | 59 | 0 |

### Sensitivity to the noise correlation

The absolute errors depend heavily on how correlated the error is between
fixes, which is an assumption of the model:

| Best / … | Straight, ρ = 0.90 | Straight, ρ = 0.97 | Straight, ρ = 0.99 |
|----------|-------------------:|-------------------:|-------------------:|
| no filter | +30.62 % | +8.60 % | +2.80 % |
| 5 m | +14.24 % | +4.11 % | +1.34 % |
| 10 m | +6.07 % | +1.95 % | +0.67 % |
| 20 m | +2.27 % | +0.46 % | −0.22 % |

On the winding route at ρ = 0.99, Best / 20 m measures −0.74 %: the filter is
now large enough that cutting corners outweighs the remaining noise.

## What the numbers do and do not support

Robust across all three correlations (and asserted in
`LocationConfigurationSimulationTests`):

1. Delivered updates fall roughly as 1 / `distanceFilter`: doubling the filter
   from 5 m to 10 m about halves them.
2. A larger `distanceFilter` reduces the distance added by GPS noise on a
   straight road, because noise between close points is summed instead of
   averaged out.
3. A larger filter starts cutting corners on winding paths (shown noise-free in
   the tests, and visible as a negative error at 20 m with low noise).
4. `NearestTenMeters` is noisier than `Best` at the same filter.
5. `HundredMeters` is unusable: its reported accuracy is above the 30 m accuracy
   threshold of `SampleValidator`, so **every** sample is rejected and the run
   records 0 m.

Not robust: the percentages. They move by a factor of 10 between ρ = 0.90 and
ρ = 0.99, so only their ordering should be read, not their size. The σ per
accuracy level is also an assumption.

## What was not measured

- **Battery.** A simulator cannot measure it, and none of the figures above is a
  battery figure. What can be said qualitatively: the GPS radio cost follows
  `desiredAccuracy`, while `distanceFilter` mainly reduces how often the app is
  woken and writes to disk. Whether going from 5 m to 10 m saves a noticeable
  amount of battery is exactly what the device protocol below is for.
- Real GPS error, which depends on the device, sky view, buildings and weather.
- Real `distanceFilter` behavior, which CoreLocation applies with its own
  internal timing and which is only approximated by the model.

## Manual protocol on a device — **not executed**

Run each configuration for the same route and duration, starting from a similar
battery level, with the screen locked, no other apps open and the same network:

1. Walk or run a 30 minute loop of known length with `Best / 5 m`. Note the
   battery percentage before and after, and the distance STRIDE reports.
2. Repeat with `Best / 10 m` (change `LocationConfiguration.default`).
3. Repeat with a third configuration if wanted, e.g. `NearestTenMeters / 10 m`.
4. Compare the reported distance with the known length of the loop, and the
   battery drop per configuration. Repeat at least three times: a single run is
   dominated by GPS conditions of the day.

Xcode's Energy Organizer or the Energy gauge in Instruments gives a finer
reading than the battery percentage, if a device is connected.

Results of this protocol are **not** recorded here: no device measurement has
been made.
