import SwiftUI

/// Route plus summary of one completed run.
struct RunDetailsView: View {
    let history: HistoryModel
    let runId: UUID
    @Environment(AppSettings.self) private var settings
    @Environment(HealthSync.self) private var healthSync

    @State private var run: RunRecord?
    @State private var route = Route()

    var body: some View {
        Group {
            if let run {
                ScrollView {
                    VStack(spacing: 16) {
                        RouteMapView(route: route, mode: .completed)
                            .brandMapFrame()
                            .containerRelativeFrame(.vertical) { height, _ in max(260, height * 0.45) }
                        stats(run)
                        times(run)
                        healthStatus
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("Run not found", systemImage: "questionmark.folder")
                    .padding()
                    .brandCard()
                    .padding()
            }
        }
        .brandScreen()
        .navigationTitle(Text(run?.startedAt.formatted(date: .abbreviated, time: .omitted) ?? String(localized: "Run")))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: runId) {
            run = history.run(id: runId)
            route = history.route(of: runId)
        }
    }

    /// How saving this run to Health went; only known for a run finished during this launch.
    @ViewBuilder private var healthStatus: some View {
        if let outcome = healthSync.outcomes[runId] {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(Self.message(for: outcome))
                } icon: {
                    Image(systemName: outcome.isSaved ? "heart.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(outcome.isSaved ? .pink : .orange)
                }
                .font(.subheadline)
                if outcome == .failed {
                    Button("Try again") { Task { await healthSync.runFinished(runId) } }
                        .buttonStyle(.brandFilled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .brandCard()
            .accessibilityIdentifier("healthStatus")
        }
    }

    private static func message(for outcome: HealthSync.Outcome) -> LocalizedStringResource {
        switch outcome {
        case .saved: "Saved to Health"
        case .savedWithoutRoute: "Saved to Health without the route"
        case .accessDenied: "STRIDE can't save to Health. Allow it in the Health settings of your iPhone."
        case .failed: "Couldn't save the run to Health."
        }
    }

    private func stats(_ run: RunRecord) -> some View {
        let unit = settings.distanceUnit
        return AdaptiveStack {
            StatTile(
                title: "Distance", unit: unit.distanceSymbol,
                value: DistanceFormat.distance(run.distance, unit: unit),
                spokenValue: SpokenFormat.distance(run.distance, unit: unit)
            )
            StatTile(
                title: "Duration",
                value: RunSummary.duration(run),
                spokenValue: SpokenFormat.duration(run.accumulatedDuration)
            )
            StatTile(
                title: "Avg", unit: unit.paceSuffix,
                value: PaceFormat.pace(run.averagePace, unit: unit),
                spokenValue: SpokenFormat.pace(run.averagePace, unit: unit)
            )
        }
        .frame(maxWidth: .infinity)
        .padding()
        .brandCard()
    }

    private func times(_ run: RunRecord) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                startLabel(run)
                Spacer()
                finishLabel(run)
            }
            VStack(alignment: .leading, spacing: 8) {
                startLabel(run)
                finishLabel(run)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding()
        .brandCard()
    }

    private func startLabel(_ run: RunRecord) -> some View {
        Label(run.startedAt.formatted(date: .omitted, time: .shortened), systemImage: "flag.fill")
    }

    @ViewBuilder
    private func finishLabel(_ run: RunRecord) -> some View {
        if let finishedAt = run.finishedAt {
            Label(finishedAt.formatted(date: .omitted, time: .shortened), systemImage: "flag.checkered")
        }
    }
}
