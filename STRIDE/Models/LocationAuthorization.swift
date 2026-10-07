import CoreLocation

/// App-level view of the CoreLocation authorization, decoupled from `CLAuthorizationStatus`.
enum LocationAuthorization: Sendable, Equatable {
    case notDetermined
    case restricted
    case denied
    case whenInUse
    case always

    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorizedWhenInUse: self = .whenInUse
        case .authorizedAlways: self = .always
        @unknown default: self = .denied
        }
    }

    /// Location can be read in this state.
    var canTrack: Bool { self == .whenInUse || self == .always }

    /// The system permission prompt can still be shown.
    var canRequest: Bool { self == .notDetermined }

    /// The user can fix this in the Settings app. `restricted` cannot be changed by the user.
    var canOpenSettings: Bool { self == .denied }

    /// Message for the Tracking screen, `nil` when nothing needs to be explained.
    var message: String? {
        switch self {
        case .notDetermined, .always:
            nil
        case .denied:
            "Location access is off. STRIDE needs it to record your route."
        case .restricted:
            "Location is restricted on this device."
        case .whenInUse:
            "Runs keep recording in the background while a run is in progress."
        }
    }
}
