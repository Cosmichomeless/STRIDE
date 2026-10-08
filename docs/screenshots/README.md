# Screenshots

| File | What it shows |
|------|---------------|
| `00-showcase.png` | The cover used at the top of the README (1200x560). Built from the icon and two of the screenshots below. |
| `01-tracking-idle.png` | Tracking tab with a GPS fix, before starting a run. |
| `02-tracking-active.png` | A run in progress with the live route. |
| `03-run-details.png` | The finished run on a map. |
| `04-history.png` | The history list with that run. |

All of them come from one synthetic run in the iPhone 17 Pro simulator (a loop through the Retiro park, Madrid), in light mode. They contain no personal data. The two procedures below are independent: rebuilding the cover does **not** recapture the app.

## Recapturing the screenshots

`STRIDEUITests/ScreenshotWalkthroughTests.swift` is an XCUITest that sets a simulated location, starts a run, walks a synthetic route one fix per second, finishes the run and saves a full-resolution PNG of each screen. It is not a regression test, so it lives in its own scheme and takes about 2.5 minutes.

```bash
xcodegen generate
mkdir -p /tmp/stride-shots
TEST_RUNNER_SHOTS_DIR=/tmp/stride-shots \
xcodebuild test -project STRIDE.xcodeproj -scheme STRIDEScreenshots \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

`TEST_RUNNER_SHOTS_DIR` reaches the test as `SHOTS_DIR`; without it nothing is saved.

Things the test handles, and things to check by hand:

- It finishes any restored run and deletes every history row first, so the history shows only the new run. This **deletes the app's runs in that simulator**.
- It accepts the location permission dialog (English and Spanish buttons) and nudges the simulated location until the screen says "GPS ready".
- The status bar shows the real time, and the map labels follow the simulator's language. Look at each PNG before keeping it: no accidental states (loading, permission dialogs, "GPS signal lost"), no personal data.

The originals are 1206x2622, too heavy for the repository, so they are optimized before being committed.

## Optimizing the PNGs

Each file is resized to 700 px wide and quantized to a 256-color palette with dithering, which keeps every file under 400 KB:

```python
from PIL import Image

im = Image.open("original.png").convert("RGB")
height = round(im.height * 700 / im.width)
q = im.resize((700, height), Image.LANCZOS).quantize(
    colors=256,
    method=Image.Quantize.MEDIANCUT,      # 01, 02 and 03; use MAXCOVERAGE for 04
    dither=Image.Dither.FLOYDSTEINBERG,
)
q.save("docs/screenshots/NN-name.png", optimize=True)
```

`MEDIANCUT` renders the gradient and the maps best but shifts the grey text on the plain gradient screen (`04-history.png`), where `MAXCOVERAGE` keeps the text colors. Compare the result with the original: numbers, titles and buttons must stay legible. Done with Pillow 11.

## Rebuilding the cover

```bash
python3 -m pip install Pillow
python3 docs/screenshots/build-showcase.py
```

The script reads only versioned files (the app icon, `02-tracking-active.png` and `03-run-details.png`) and writes `00-showcase.png`. The output is deterministic: running it twice gives the same SHA-1 (`shasum docs/screenshots/00-showcase.png`). Crops, sizes and the background gradient (the icon's orange and crimson) are constants at the top of the script.
