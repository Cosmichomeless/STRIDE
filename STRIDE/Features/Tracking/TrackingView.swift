import SwiftUI

struct TrackingView: View {
    @State var location: LocationService

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 16) {
                LocationStatusView(
                    authorization: location.authorization,
                    gpsStatus: location.gpsStatus(now: context.date),
                    onRequestAuthorization: location.requestAuthorization
                )
                Spacer()
            }
            .padding()
        }
        // Warm up the GPS so a fix is ready when the user taps Start.
        .onAppear { location.startUpdates() }
        .onChange(of: location.authorization) { _, _ in location.startUpdates() }
    }
}
