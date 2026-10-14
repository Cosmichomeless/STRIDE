import SwiftUI

/// Route plus summary of one completed run.
struct RunDetailsView: View {
    let history: HistoryModel
    let runId: UUID
    @Environment(AppSettings.self) private var settings

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
