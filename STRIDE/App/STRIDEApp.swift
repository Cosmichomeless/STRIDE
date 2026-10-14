import SwiftData
import SwiftUI

@main
struct STRIDEApp: App {
    private let container: ModelContainer
    @State private var coordinator: TrackingCoordinator
    @State private var history: HistoryModel
    @State private var settings: AppSettings
    @State private var healthSync: HealthSync
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container: ModelContainer
        do {
            container = try StrideSchema.makeContainer()
        } catch {
            fatalError("Cannot open the run database: \(error)")
        }
        self.container = container
        // UI tests start from the defaults a fresh install would have.
        if ProcessInfo.processInfo.arguments.contains("-uitest-reset-settings"),
           let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        let store = SwiftDataRunStore(container: container)
        let health: any HealthWriting = ProcessInfo.processInfo.arguments.contains("-uitest-fake-health")
            ? StubHealthWriter() : HealthKitWriter()
        _healthSync = State(initialValue: HealthSync(health: health, settings: settings, store: store))
        _coordinator = State(initialValue: TrackingCoordinator(location: LocationService(), store: store))
        _history = State(initialValue: HistoryModel(store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator, history: history, settings: settings, healthSync: healthSync)
                // Foreground: warm up the GPS so a fix is ready for Start. Background: release it
                // unless a run is active (see docs/BACKGROUND.md).
                .onChange(of: scenePhase, initial: true) { _, phase in
                    switch phase {
                    case .active:
                        coordinator.appDidBecomeActive()
                        healthSync.refreshAccess()
                    case .background: coordinator.appDidEnterBackground()
                    default: break
                    }
                }
        }
        .modelContainer(container)
    }
}
