import SwiftUI

struct RootView: View {
    let coordinator: TrackingCoordinator
    let history: HistoryModel
    @State private var navigation = AppNavigation()

    var body: some View {
        TabView(selection: $navigation.selection) {
            Tab("Tracking", systemImage: "figure.run", value: AppTab.tracking) {
                TrackingView(coordinator: coordinator)
            }
            Tab("History", systemImage: "list.bullet", value: AppTab.history) {
                HistoryView(history: history, navigation: navigation)
            }
        }
        .onChange(of: coordinator.session.state) { _, state in
            guard state == .finished, let id = coordinator.runId else { return }
            history.reload()
            navigation.showFinishedRun(id)
        }
    }
}
