# STRIDE — Maps

How routes are modeled and drawn with MapKit.

## Route model

`Route` (`Maps/Route.swift`) is plain values (no MapKit) so it is unit-tested:

- It groups the **accepted** points in segments. A new segment starts at the first
  point, after a pause and after a gap (`startsSegment`, the same flag used for
  distance), so a pause or a process kill is never drawn as a straight line.
- `TrackingCoordinator.route` is appended to in the same place as the metrics
  (`receive`), so rejected samples never reach the map.
- After a relaunch the route is rebuilt from the stored points, like the metrics.
- A finished run keeps its route until a new run starts, so the Tracking screen can
  show the completed route.

## Framing

`Route.framing` returns the center and span that fit every segment, padded by 30 %
with a minimum span of 0.002° (~220 m), so a run that barely moved does not zoom in
to street level. An empty route has no framing (map falls back to `.automatic`).
Routes crossing the antimeridian are not handled (not a running use case).

## Views

`RouteMapView` (`Maps/RouteMapView.swift`):

| Mode | Camera | Content |
|------|--------|---------|
| `live` (active / paused run) | Follows the user (`.userLocation`), falling back to the route framing until there is a fix | User position, one polyline per segment |
| `completed` (finished run) | Route framing | Polylines plus start and finish markers |

Single-point segments draw no line. The map offers the user-location button so the
user can re-center after panning.

## Verification status

Route grouping, rebuilding and framing are covered by deterministic tests
(`RouteTests`, route cases in `TrackingCoordinatorTests`). The rendering itself
(polyline look, camera behavior with a real GPS) has **not** been verified on a
device; the simulator has no moving GPS fix without a scheduled location.
