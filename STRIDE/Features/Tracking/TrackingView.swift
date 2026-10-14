import SwiftUI

struct TrackingView: View {
    let coordinator: TrackingCoordinator
    @Environment(AppSettings.self) private var settings

    @ScaledMetric private var timerSize: CGFloat = 64

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            // Scrolls when text is large; otherwise it fills the screen and the map takes the spare height.
            GeometryReader { proxy in
                ScrollView {
                    content(at: context.date)
                        .padding()
                        .frame(minHeight: proxy.size.height)
                }
            }
        }
        .brandScreen()
    }

    private func content(at date: Date) -> some View {
        VStack(spacing: 20) {
            LocationStatusView(
                authorization: coordinator.location.authorization,
                gpsStatus: coordinator.location.gpsStatus(now: date),
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

            Text(DurationFormat.clock(coordinator.elapsed(at: date)))
                .font(.system(size: timerSize, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityLabel(Text("Elapsed time"))
                .accessibilityValue(SpokenFormat.duration(coordinator.elapsed(at: date)))

            if let goal = settings.goal {
                GoalProgressCard(
                    goal: goal,
                    distance: coordinator.metrics.distance,
                    elapsed: coordinator.elapsed(at: date),
                    unit: settings.distanceUnit
                )
            }

            stats(at: date)
            controls
            routeMap
        }
    }

    /// Live map while recording, the framed route once finished. Hidden when there is nothing to show.
    @ViewBuilder private var routeMap: some View {
        switch coordinator.session.state {
        case .active, .paused:
            RouteMapView(route: coordinator.route, mode: .live)
                .brandMapFrame()
                .frame(minHeight: 260)
        case .finished where !coordinator.route.isEmpty:
            RouteMapView(route: coordinator.route, mode: .completed)
                .brandMapFrame()
                .frame(minHeight: 260)
        case .idle, .finished:
            Spacer()
        }
    }

    private func stats(at date: Date) -> some View {
        let unit = settings.distanceUnit
        let current = coordinator.currentPace(at: date)
        let average = coordinator.averagePace(at: date)
        return AdaptiveStack {
            StatTile(
                title: "Distance", unit: unit.distanceSymbol,
                value: DistanceFormat.distance(coordinator.metrics.distance, unit: unit),
                spokenValue: SpokenFormat.distance(coordinator.metrics.distance, unit: unit)
            )
            StatTile(
                title: "Pace", unit: unit.paceSuffix,
                value: PaceFormat.pace(current, unit: unit),
                spokenValue: SpokenFormat.pace(current, unit: unit)
            )
            StatTile(
                title: "Avg", unit: unit.paceSuffix,
                value: PaceFormat.pace(average, unit: unit),
                spokenValue: SpokenFormat.pace(average, unit: unit)
            )
        }
        .frame(maxWidth: .infinity)
        .padding()
        .brandCard()
    }

    @ViewBuilder private var controls: some View {
        switch coordinator.session.state {
        case .idle, .finished:
            Button(startTitle, action: coordinator.start)
                .buttonStyle(.brandPrimary)
                .disabled(!canStart)
        case .active:
            AdaptiveStack(spacing: 8) {
                Button("Pause", action: coordinator.pause).buttonStyle(.brandSecondary)
                Button("Finish", role: .destructive, action: coordinator.finish).buttonStyle(.brandPrimary)
            }
        case .paused:
            AdaptiveStack(spacing: 8) {
                Button("Resume", action: coordinator.resume)
                    .buttonStyle(.brandPrimary)
                    .disabled(!coordinator.location.authorization.canTrack)
                Button("Finish", role: .destructive, action: coordinator.finish).buttonStyle(.brandSecondary)
            }
        }
    }

    /// Typed as a key so the ternary is localized instead of becoming a plain `String`.
    private var startTitle: LocalizedStringKey {
        coordinator.session.state == .finished ? LocalizedStringKey("New Run") : LocalizedStringKey("Start")
    }

    private var canStart: Bool {
        let authorization = coordinator.location.authorization
        return authorization.canTrack || authorization.canRequest
    }
}
