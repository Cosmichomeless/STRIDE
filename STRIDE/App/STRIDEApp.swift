import SwiftUI

@main
struct STRIDEApp: App {
    @State private var location = LocationService()

    var body: some Scene {
        WindowGroup {
            TrackingView(location: location)
        }
    }
}
