import SwiftUI

struct HistoryView: View {
    let history: HistoryModel
    @Bindable var navigation: AppNavigation

    var body: some View {
        NavigationStack(path: $navigation.historyPath) {
            Group {
                if let error = history.error, history.runs.isEmpty {
                    ContentUnavailableView(
                        "Cannot load runs",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error.localizedDescription)
                    )
                } else if history.runs.isEmpty {
                    ContentUnavailableView("No runs yet — go for a run", systemImage: "figure.run")
                } else {
                    list
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: UUID.self) { id in
                RunDetailsView(history: history, runId: id)
            }
        }
        .onAppear { history.reload() }
    }

    private var list: some View {
        List {
            ForEach(history.runs) { run in
                NavigationLink(value: run.id) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)
                        Text(RunSummary.line(run))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .onDelete { offsets in
                for index in offsets { history.delete(runId: history.runs[index].id) }
            }
        }
    }
}
