import Foundation
import Testing
@testable import STRIDE

struct RouteTests {
    private func sample(_ lat: Double, _ lon: Double) -> LocationSample {
        LocationSample(latitude: lat, longitude: lon, altitude: 0, horizontalAccuracy: 5, speed: -1, timestamp: Date(timeIntervalSince1970: 0))
    }

    @Test func emptyRouteHasNoFraming() {
        let route = Route()
        #expect(route.isEmpty)
        #expect(route.pointCount == 0)
        #expect(route.framing == nil)
        #expect(route.first == nil && route.last == nil)
    }

    @Test func pointsAreGroupedInSegments() {
        var route = Route()
        route.add(sample(40.000, -3), startsSegment: true)
        route.add(sample(40.001, -3), startsSegment: false)
        route.add(sample(40.002, -3), startsSegment: false)
        route.add(sample(40.010, -3), startsSegment: true)   // after a pause or a gap
        route.add(sample(40.011, -3), startsSegment: false)
        #expect(route.segments.map(\.count) == [3, 2])
        #expect(route.pointCount == 5)
        #expect(route.first == RouteCoordinate(latitude: 40.000, longitude: -3))
        #expect(route.last == RouteCoordinate(latitude: 40.011, longitude: -3))
    }

    @Test func aPointWithoutAnOpenSegmentStartsOne() {
        var route = Route()
        route.add(sample(40, -3), startsSegment: false)
        #expect(route.segments.count == 1)
    }

    @Test func routeIsRebuiltFromStoredPoints() {
        let points = [
            TrackPoint(sample: sample(40.000, -3), startsSegment: true),
            TrackPoint(sample: sample(40.001, -3), startsSegment: false),
            TrackPoint(sample: sample(40.005, -3), startsSegment: true),
        ]
        let route = Route(points: points)
        #expect(route.segments.map(\.count) == [2, 1])
    }

    @Test func framingCentersOnTheRouteWithPadding() throws {
        var route = Route()
        route.add(sample(40.00, -3.00), startsSegment: true)
        route.add(sample(40.02, -2.96), startsSegment: false)
        let region = try #require(route.framing)
        #expect(abs(region.center.latitude - 40.01) < 1e-9)
        #expect(abs(region.center.longitude - -2.98) < 1e-9)
        #expect(abs(region.latitudeSpan - 0.02 * Route.framingPadding) < 1e-9)
        #expect(abs(region.longitudeSpan - 0.04 * Route.framingPadding) < 1e-9)
    }

    @Test func framingCoversEverySegment() throws {
        var route = Route()
        route.add(sample(40.00, -3), startsSegment: true)
        route.add(sample(40.01, -3), startsSegment: false)
        route.add(sample(40.10, -3), startsSegment: true)
        let region = try #require(route.framing)
        #expect(region.center.latitude > 40.04 && region.center.latitude < 40.06)
        #expect(region.latitudeSpan >= 0.10)
    }

    @Test func tinyRoutesKeepAMinimumSpan() throws {
        var route = Route()
        route.add(sample(40, -3), startsSegment: true)
        let single = try #require(route.framing)
        #expect(single.latitudeSpan == Route.minimumSpan)
        #expect(single.longitudeSpan == Route.minimumSpan)

        route.add(sample(40.00001, -3.00001), startsSegment: false)
        let near = try #require(route.framing)
        #expect(near.latitudeSpan == Route.minimumSpan)
    }
}
