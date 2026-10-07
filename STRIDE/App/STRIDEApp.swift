import SwiftData
import SwiftUI

@main
struct STRIDEApp: App {
    private let container: ModelContainer
    @State private var coordinator: TrackingCoordinator
    @State private var history: HistoryModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container: ModelContainer
        do {
            container = try StrideSchema.makeContainer()
        } catch {
            fatalError("Cannot open the run database: \(error)")
        }
        self.container = container
        let store = SwiftDataRunStore(container: container)
        _coordinator = State(initialValue: TrackingCoordinator(location: LocationService(), store: store))
        _history = State(initialValue: HistoryModel(store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator, history: history)
                // Foreground: warm up the GPS so a fix is ready for Start. Background: release it
                // unless a run is active (see docs/BACKGROUND.md).
                .onChange(of: scenePhase, initial: true) { _, phase in
                    switch phase {
                    case .active: coordinator.appDidBecomeActive()
                    case .background: coordinator.appDidEnterBackground()
                    default: break
                    }
                }
        }
        .modelContainer(container)
    }
}
