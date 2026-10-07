# STRIDE — History and run details

Implementation notes for the History tab and the Run details screen (flows are
defined in PRODUCT.md).

## Structure

| Piece | Role |
|-------|------|
| `RootView` | `TabView` with Tracking and History. |
| `AppNavigation` | Selected tab and the History navigation path. Always starts on **Tracking**, so a run restored after a relaunch is what the user sees first. |
| `HistoryModel` | Completed runs (newest first), delete, and the route/record of one run. Reads the same `RunStore` the coordinator writes to. |
| `HistoryView` | List with swipe-to-delete, empty state "No runs yet — go for a run", and an error state if the store cannot be read (an empty list would look like data loss). |
| `RunDetailsView` | Completed route on a map (`RouteMapView`, mode `completed`), distance, duration, average pace, start and finish time. |
| `RunSummary` | Text formatting shared by rows and details. |

## Behavior

- When the coordinator's session becomes `finished`, `RootView` reloads History
  and calls `AppNavigation.showFinishedRun`, which switches to History and pushes
  the details of that run.
- Deleting a run removes its points too (`RunStore.delete`).
- A run without distance shows `--` as pace instead of a meaningless number.
- History and details only read persisted data, so they work without location
  permission.

## Verification status

`HistoryTests` cover ordering, filtering of in-progress runs, reload, delete with
points, route rebuilding, summary text and the navigation rules. The SwiftUI screens
themselves (layout, swipe gesture, the push animation) have not been exercised in a
UI test or on a device.
