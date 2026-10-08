import SwiftUI

/// Route plus summary of one completed run.
struct RunDetailsView: View {
    let history: HistoryModel
    let runId: UUID

    @State private var run: RunRecord?
    @State private var route = Route()

    var body: some View {
        Group {
            if let run {
                VStack(spacing: 16) {
                    RouteMapView(route: route, mode: .completed)
                        .brandMapFrame()
                    stats(run)
                    times(run)
                }
                .padding()
            } else {
                ContentUnavailableView("Run not found", systemImage: "questionmark.folder")
                    .padding()
                    .brandCard()
                    .padding()
            }
        }
        .brandScreen()
        .navigationTitle(run?.startedAt.formatted(date: .abbreviated, time: .omitted) ?? "Run")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: runId) {
            run = history.run(id: runId)
            route = history.route(of: runId)
        }
    }

    private func stats(_ run: RunRecord) -> some View {
        HStack(spacing: 24) {
            stat("Distance (km)", DistanceFormat.kilometers(run.distance))
            stat("Duration", RunSummary.duration(run))
            stat("Avg (/km)", PaceFormat.pace(run.averagePace))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .brandCard()
    }

    private func times(_ run: RunRecord) -> some View {
        HStack {
            Label(run.startedAt.formatted(date: .omitted, time: .shortened), systemImage: "flag.fill")
            Spacer()
            if let finishedAt = run.finishedAt {
                Label(finishedAt.formatted(date: .omitted, time: .shortened), systemImage: "flag.checkered")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
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
}
