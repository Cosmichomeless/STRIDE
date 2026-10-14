import Foundation
import Observation
import SwiftUI

/// User preferences, kept in `UserDefaults`. Every change is written immediately, so the next
/// launch starts with the same choices.
@MainActor
@Observable
final class AppSettings {
    enum Appearance: String, CaseIterable, Sendable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        /// `nil` follows the system.
        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }

        var name: LocalizedStringResource {
            switch self {
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            }
        }
    }

    enum GoalKind: String, CaseIterable, Sendable, Identifiable {
        case none, distance, time

        var id: String { rawValue }

        var name: LocalizedStringResource {
            switch self {
            case .none: "None"
            case .distance: "Distance"
            case .time: "Time"
            }
        }
    }

    enum Key {
        static let distanceUnit = "settings.distanceUnit"
        static let appearance = "settings.appearance"
        static let goalKind = "settings.goalKind"
        static let goalDistance = "settings.goalDistanceMeters"
        static let goalTime = "settings.goalTimeSeconds"
        static let saveToHealth = "settings.saveToHealth"
    }

    /// Goal limits and the size of one stepper tap.
    static let distanceStep = 0.5
    static let distanceRange: ClosedRange<Double> = 0.5...100
    static let timeStep: TimeInterval = 300
    static let timeRange: ClosedRange<TimeInterval> = 300...36_000
    /// What a stored distance goal (meters) may be, wide enough for both units.
    static let storedDistanceRange: ClosedRange<Double> = 100...200_000
    static let defaultGoalDistance = 5_000.0
    static let defaultGoalTime: TimeInterval = 1_800

    var distanceUnit: DistanceUnit {
        didSet { defaults.set(distanceUnit.rawValue, forKey: Key.distanceUnit) }
    }
    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }
    var goalKind: GoalKind {
        didSet { defaults.set(goalKind.rawValue, forKey: Key.goalKind) }
    }
    /// Distance goal in meters, whatever unit it is shown in.
    var goalDistance: Double {
        didSet { defaults.set(goalDistance, forKey: Key.goalDistance) }
    }
    var goalTime: TimeInterval {
        didSet { defaults.set(goalTime, forKey: Key.goalTime) }
    }
    /// Write finished runs to Apple Health.
    var saveToHealth: Bool {
        didSet { defaults.set(saveToHealth, forKey: Key.saveToHealth) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// `locale` only decides the unit of a first launch; after that the user's choice wins.
    init(defaults: UserDefaults = .standard, locale: Locale = .current) {
        self.defaults = defaults
        distanceUnit = defaults.string(forKey: Key.distanceUnit).flatMap(DistanceUnit.init) ?? .default(for: locale)
        appearance = defaults.string(forKey: Key.appearance).flatMap(Appearance.init) ?? .system
        goalKind = defaults.string(forKey: Key.goalKind).flatMap(GoalKind.init) ?? .none
        let distance = defaults.object(forKey: Key.goalDistance) as? Double
        goalDistance = distance.map { Self.clamp($0, to: Self.storedDistanceRange) } ?? Self.defaultGoalDistance
        let time = defaults.object(forKey: Key.goalTime) as? Double
        goalTime = time.map { Self.clamp($0, to: Self.timeRange) } ?? Self.defaultGoalTime
        saveToHealth = defaults.object(forKey: Key.saveToHealth) as? Bool ?? true
    }

    /// The goal in force, or `nil` when the user has none.
    var goal: RunGoal? {
        switch goalKind {
        case .none: nil
        case .distance: .distance(meters: goalDistance)
        case .time: .time(seconds: goalTime)
        }
    }

    /// Moves the distance goal by whole steps of `distanceStep` in the unit being shown.
    func stepDistanceGoal(by steps: Int) {
        let current = distanceUnit.value(fromMeters: goalDistance)
        let snapped = (current / Self.distanceStep).rounded() * Self.distanceStep
        let next = Self.clamp(snapped + Double(steps) * Self.distanceStep, to: Self.distanceRange)
        goalDistance = next * distanceUnit.metersPerUnit
    }

    func stepTimeGoal(by steps: Int) {
        let snapped = (goalTime / Self.timeStep).rounded() * Self.timeStep
        goalTime = Self.clamp(snapped + Double(steps) * Self.timeStep, to: Self.timeRange)
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
