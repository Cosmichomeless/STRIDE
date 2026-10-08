import SwiftUI

struct TrackingView: View {
    let coordinator: TrackingCoordinator

    @ScaledMetric private var timerSize: CGFloat = 64

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 20) {
                LocationStatusView(
                    authorization: coordinator.location.authorization,
                    gpsStatus: coordinator.location.gpsStatus(now: context.date),
                    onRequestAuthorization: coordinator.location.requestAuthorization
                )

                if let reason = coordinator.pauseReason {
                    Label {
                        Text(reason.message)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .brandCard()
                }

                Text(DurationFormat.clock(coordinator.elapsed(at: context.date)))
                    .font(.system(size: timerSize, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityLabel("Elapsed time")

                stats(at: context.date)

                controls
                routeMap
            }
            .padding()
        }
        .brandScreen()
    }

    /// Live map while recording, the framed route once finished. Hidden when there is nothing to show.
    @ViewBuilder private var routeMap: some View {
        switch coordinator.session.state {
        case .active, .paused:
            RouteMapView(route: coordinator.route, mode: .live)
                .brandMapFrame()
        case .finished where !coordinator.route.isEmpty:
            RouteMapView(route: coordinator.route, mode: .completed)
                .brandMapFrame()
        case .idle, .finished:
            Spacer()
        }
    }

    private func stats(at date: Date) -> some View {
        HStack(spacing: 24) {
            stat("Distance (km)", DistanceFormat.kilometers(coordinator.metrics.distance))
            stat("Pace (/km)", PaceFormat.pace(coordinator.currentPace(at: date)))
            stat("Avg (/km)", PaceFormat.pace(coordinator.averagePace(at: date)))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .brandCard()
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.monospacedDigit().weight(.bold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var controls: some View {
        switch coordinator.session.state {
        case .idle, .finished:
            Button(coordinator.session.state == .finished ? "New Run" : "Start", action: coordinator.start)
                .buttonStyle(.brandPrimary)
                .disabled(!canStart)
        case .active:
            HStack {
                Button("Pause", action: coordinator.pause).buttonStyle(.brandSecondary)
                Button("Finish", role: .destructive, action: coordinator.finish).buttonStyle(.brandPrimary)
            }
        case .paused:
            HStack {
                Button("Resume", action: coordinator.resume)
                    .buttonStyle(.brandPrimary)
                    .disabled(!coordinator.location.authorization.canTrack)
                Button("Finish", role: .destructive, action: coordinator.finish).buttonStyle(.brandSecondary)
            }
        }
    }

    private var canStart: Bool {
        let authorization = coordinator.location.authorization
        return authorization.canTrack || authorization.canRequest
    }
}
