import SwiftUI

@main
struct STRIDEApp: App {
    @State private var coordinator = TrackingCoordinator(location: LocationService())

    var body: some Scene {
        WindowGroup {
            TrackingView(coordinator: coordinator)
        }
    }
}
