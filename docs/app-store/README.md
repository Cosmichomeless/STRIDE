# App Store assets

The images uploaded to App Store Connect for STRIDE 1.0, at the exact size and content that was uploaded. The listing text is in [`../STORE_LISTING.md`](../STORE_LISTING.md).

| Folder | Content |
| --- | --- |
| `screenshots/<lang>/` | The four screenshots of each language (`es`, `en`, `fr`, `de`, `it`, `pt-BR`), 1320x2868 (iPhone 6.9"), uploaded as `APP_IPHONE_67`. `01-tracking-idle`, `02-tracking-active`, `03-run-details`, `04-history`. |
| `header/` | Product page header in all six languages, at 3840x1646 and 5244x2950. |
| `search/` | Search results image in all six languages, at 5244x2950, 3840x2560 and 1920x1280. |

The screenshots are the full-resolution originals, not the optimized copies in [`../screenshots/`](../screenshots/README.md) that the README uses. They come from the synthetic run described there (a loop through the Retiro park), with the status bar fixed at 9:41.

## Recapturing the screenshots

`STRIDEUITests/ScreenshotWalkthroughTests.swift` takes `TEST_RUNNER_SHOTS_LANG` (`en`, `es`, `fr`, `de`, `it`, `pt-BR`) next to `TEST_RUNNER_SHOTS_DIR`:

```bash
xcodegen generate
xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3
for lang in es en fr de it pt-BR; do
  mkdir -p docs/app-store/screenshots/$lang
  TEST_RUNNER_SHOTS_DIR="$PWD/docs/app-store/screenshots/$lang" TEST_RUNNER_SHOTS_LANG=$lang \
  xcodebuild test -project STRIDE.xcodeproj -scheme STRIDEScreenshots -destination "id=<udid>"
done
```

Use an iPhone 6.9" simulator (iPhone 17 Pro Max). The test deletes the app's runs in that simulator.

## Rebuilding the header and the search image

```bash
python3 -m pip install Pillow
python3 docs/app-store/make_header.py
python3 docs/app-store/make_search.py
```

Both read the app icon and the screenshots in this folder and are deterministic (same bytes on every run). They use the macOS font `SF NS Rounded`, so they run on a Mac. The text of each language is the `TEXT` table at the top of each script; add a language there to get its images.

## Tools

`tools/asc_api.py` (a minimal App Store Connect API client) and `tools/submit_review.py` (sends a version to review). Both read the key from the environment; see [`../RELEASE_GUIDE.md`](../RELEASE_GUIDE.md) for the whole procedure.
