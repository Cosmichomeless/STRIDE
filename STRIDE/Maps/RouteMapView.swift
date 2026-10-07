import MapKit
import SwiftUI

/// Draws a route on a map. `live` follows the user while recording; `completed` frames the whole
/// route. Both draw each segment as its own polyline so pauses and gaps are not connected.
struct RouteMapView: View {
    enum Mode { case live, completed }

    let route: Route
    let mode: Mode

    @State private var position: MapCameraPosition

    init(route: Route, mode: Mode) {
        self.route = route
        self.mode = mode
        _position = State(initialValue: Self.position(for: route, mode: mode))
    }

    var body: some View {
        Map(position: $position) {
            if mode == .live { UserAnnotation() }
            ForEach(Array(route.segments.enumerated()), id: \.offset) { _, segment in
                if segment.count > 1 {
                    MapPolyline(coordinates: segment.map(\.clCoordinate))
                        .stroke(.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            }
            if mode == .completed {
                if let start = route.first { Marker("Start", systemImage: "flag.fill", coordinate: start.clCoordinate).tint(.green) }
                if let end = route.last { Marker("Finish", systemImage: "flag.checkered", coordinate: end.clCoordinate).tint(.red) }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        // The first points give the camera something to frame while there is no user fix yet.
        .onChange(of: route.isEmpty) { _, _ in position = Self.position(for: route, mode: mode) }
        .accessibilityLabel(mode == .live ? "Live route map" : "Completed route map")
    }

    static func position(for route: Route, mode: Mode) -> MapCameraPosition {
        switch mode {
        case .live:
            return .userLocation(followsHeading: false, fallback: fallback(for: route))
        case .completed:
            return fallback(for: route)
        }
    }

    private static func fallback(for route: Route) -> MapCameraPosition {
        guard let framing = route.framing else { return .automatic }
        return .region(framing.mkRegion)
    }
}

extension RouteCoordinate {
    var clCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

extension RouteRegion {
    var mkRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: center.clCoordinate,
            span: MKCoordinateSpan(latitudeDelta: latitudeSpan, longitudeDelta: longitudeSpan)
        )
    }
}
