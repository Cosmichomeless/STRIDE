import Foundation
import Testing
@testable import STRIDE

struct LocationSampleTests {
    @Test func samplesWithSameValuesAreEqual() {
        let date = Date(timeIntervalSince1970: 0)
        let a = LocationSample(latitude: 1, longitude: 2, altitude: 3, horizontalAccuracy: 5, speed: 2, timestamp: date)
        let b = a
        #expect(a == b)
    }
}
