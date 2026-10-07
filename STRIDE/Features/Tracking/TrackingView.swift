import SwiftUI

struct TrackingView: View {
    let coordinator: TrackingCoordinator

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 24) {
                LocationStatusView(
                    authorization: coordinator.location.authorization,
                    gpsStatus: coordinator.location.gpsStatus(now: context.date),
                    onRequestAuthorization: coordinator.location.requestAuthorization
                )

                Text(DurationFormat.clock(coordinator.elapsed(at: context.date)))
                    .font(.system(size: 64, weight: .semibold, design: .rounded).monospacedDigit())
                    .accessibilityLabel("Elapsed time")

                controls
                Spacer()
            }
            .padding()
        }
        // Warm up the GPS so a fix is ready when the user taps Start.
        .onAppear { coordinator.location.startUpdates() }
    }

    @ViewBuilder private var controls: some View {
        switch coordinator.session.state {
        case .idle, .finished:
            Button(coordinator.session.state == .finished ? "New Run" : "Start", action: coordinator.start)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canStart)
        case .active:
            HStack {
                Button("Pause", action: coordinator.pause).buttonStyle(.bordered)
                Button("Finish", role: .destructive, action: coordinator.finish).buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        case .paused:
            HStack {
                Button("Resume", action: coordinator.resume).buttonStyle(.borderedProminent)
                Button("Finish", role: .destructive, action: coordinator.finish).buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
    }

    private var canStart: Bool {
        let authorization = coordinator.location.authorization
        return authorization.canTrack || authorization.canRequest
    }
}
