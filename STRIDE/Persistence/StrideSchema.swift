import Foundation
import SwiftData

enum StrideSchema {
    static let models: [any PersistentModel.Type] = [Run.self, LocationPoint.self]

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
