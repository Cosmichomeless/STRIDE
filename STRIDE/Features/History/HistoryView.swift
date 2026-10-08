import SwiftUI

struct HistoryView: View {
    let history: HistoryModel
    @Bindable var navigation: AppNavigation

    var body: some View {
        NavigationStack(path: $navigation.historyPath) {
            Group {
                if let error = history.error, history.runs.isEmpty {
                    emptyState {
                        ContentUnavailableView(
                            "Cannot load runs",
                            systemImage: "exclamationmark.triangle",
                            description: Text(error.localizedDescription)
                        )
                    }
                } else if history.runs.isEmpty {
                    emptyState {
                        ContentUnavailableView("No runs yet — go for a run", systemImage: "figure.run")
                    }
                } else {
                    list
                }
            }
            .navigationTitle("History")
            .brandScreen()
            .navigationDestination(for: UUID.self) { id in
                RunDetailsView(history: history, runId: id)
            }
        }
        .onAppear { history.reload() }
    }

    /// Secondary text is not readable straight on the gradient, so the message sits on a card.
    private func emptyState<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding()
            .brandCard()
            .padding()
    }

    private var list: some View {
        List {
            ForEach(history.runs) { run in
                NavigationLink(value: run.id) {
                    HStack(spacing: 12) {
                        BrandBadge(systemImage: "figure.run")
                        VStack(alignment: .leading, spacing: 4) {
                            Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.headline)
                            Text(RunSummary.line(run))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                .listRowBackground(
                    BrandCardShape(cornerRadius: 16)
                        .fill(Color(uiColor: .systemBackground))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                )
                .listRowInsets(EdgeInsets(top: 12, leading: 32, bottom: 12, trailing: 32))
                .listRowSeparator(.hidden)
            }
            .onDelete { offsets in
                for index in offsets { history.delete(runId: history.runs[index].id) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
