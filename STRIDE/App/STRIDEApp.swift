import SwiftData
import SwiftUI

@main
struct STRIDEApp: App {
    private let container: ModelContainer
    @State private var coordinator: TrackingCoordinator

    init() {
        let container: ModelContainer
        do {
            container = try StrideSchema.makeContainer()
        } catch {
            fatalError("Cannot open the run database: \(error)")
        }
        self.container = container
        _coordinator = State(initialValue: TrackingCoordinator(
            location: LocationService(),
            store: SwiftDataRunStore(container: container)
        ))
    }

    var body: some Scene {
        WindowGroup {
            TrackingView(coordinator: coordinator)
        }
        .modelContainer(container)
    }
}
