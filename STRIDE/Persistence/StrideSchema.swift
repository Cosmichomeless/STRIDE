import Foundation
import SwiftData

enum StrideSchema {
    static let models: [any PersistentModel.Type] = [Run.self, LocationPoint.self]

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if !inMemory {
            // On a first launch the directory may not exist yet and the store would log CoreData errors.
            try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        }
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
