import Foundation

enum RejectionReason: String, Sendable, CaseIterable {
    /// `horizontalAccuracy < 0`: CoreLocation says the coordinate is not valid.
    case invalidAccuracy
    /// Fix is valid but too imprecise to trust.
    case lowAccuracy
    /// Cached/old fix delivered late.
    case stale
    /// Timestamp precedes the start of the segment (typical cached fix right after Start).
    case beforeSegmentStart
    /// Timestamp is not after the last accepted sample.
    case outOfOrder
    /// Practically the same coordinate as the last accepted sample.
    case duplicate
    /// The jump from the last accepted sample implies an impossible speed.
    case impossibleJump
    /// The speed reported by the device is impossible for running.
    case impossibleReportedSpeed
}

enum FilterDecision: Sendable, Equatable {
    case accepted
    case rejected(RejectionReason)

    var isAccepted: Bool { self == .accepted }
}

/// Stateless rules that decide whether a sample can be trusted.
/// Thresholds and their rationale are documented in `docs/GPS_FILTERING.md`.
struct SampleFilter: Sendable, Equatable {
    /// Reject fixes with a radius of uncertainty above this (m).
    var maxHorizontalAccuracy: Double = 30
    /// Reject fixes whose timestamp is older than this relative to arrival time (s).
    var maxSampleAge: TimeInterval = 10
    /// Fastest plausible running speed (m/s) ≈ 43 km/h, above the 100 m world record pace.
    var maxSpeed: Double = 12
    /// Closer than this (m) to the last accepted sample counts as the same position.
    var minDistance: Double = 1

    /// - Parameters:
    ///   - previous: last *accepted* sample of the current segment, `nil` at a segment start.
    ///   - now: arrival time of the sample.
    ///   - notBefore: samples timestamped before this are rejected (segment start).
    func evaluate(_ sample: LocationSample, previous: LocationSample?, now: Date, notBefore: Date? = nil) -> FilterDecision {
        if sample.horizontalAccuracy < 0 { return .rejected(.invalidAccuracy) }
        if sample.horizontalAccuracy > maxHorizontalAccuracy { return .rejected(.lowAccuracy) }
        if let notBefore, sample.timestamp < notBefore { return .rejected(.beforeSegmentStart) }
        if now.timeIntervalSince(sample.timestamp) > maxSampleAge { return .rejected(.stale) }
        if sample.speed > maxSpeed { return .rejected(.impossibleReportedSpeed) }

        guard let previous else { return .accepted }

        let dt = sample.timestamp.timeIntervalSince(previous.timestamp)
        if dt <= 0 { return .rejected(.outOfOrder) }

        let distance = Geodesy.distance(from: previous, to: sample)
        if distance < minDistance { return .rejected(.duplicate) }
        // The reference is the last *accepted* sample, so `dt` keeps growing while samples are
        // rejected: a real displacement (tunnel, GPS outage) becomes plausible again by itself.
        if distance / dt > maxSpeed { return .rejected(.impossibleJump) }
        return .accepted
    }
}

/// Applies `SampleFilter` along a stream: remembers the last accepted sample and counts rejections.
struct SampleValidator: Sendable {
    let filter: SampleFilter
    private(set) var lastAccepted: LocationSample?
    private(set) var rejections: [RejectionReason: Int] = [:]
    private var segmentStart: Date?

    init(filter: SampleFilter = SampleFilter(), segmentStart: Date? = nil) {
        self.filter = filter
        self.segmentStart = segmentStart
    }

    var rejectedCount: Int { rejections.values.reduce(0, +) }

    /// The next accepted sample starts a new segment: it is not connected to the previous one.
    /// Call after a pause, a recovery gap or a restart.
    mutating func beginSegment(at start: Date) {
        lastAccepted = nil
        segmentStart = start
    }

    /// Returns the decision; `accepted` samples become the new reference.
    mutating func process(_ sample: LocationSample, now: Date) -> FilterDecision {
        let decision = filter.evaluate(sample, previous: lastAccepted, now: now, notBefore: segmentStart)
        switch decision {
        case .accepted: lastAccepted = sample
        case .rejected(let reason): rejections[reason, default: 0] += 1
        }
        return decision
    }
}
