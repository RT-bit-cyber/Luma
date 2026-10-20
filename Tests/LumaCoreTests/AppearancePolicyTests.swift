import XCTest
@testable import LumaCore

final class AppearancePolicyTests: XCTestCase {
    func testDarknessMustPersistAndZeroIsValid() {
        var p = AppearancePolicy(delay: 4)
        XCTAssertNil(p.update(lux: 0, current: .light, now: 0))
        XCTAssertNil(p.update(lux: 0, current: .light, now: 2))
        XCTAssertEqual(p.update(lux: 0, current: .light, now: 4), .dark)
    }
    func testBriefShadowAndNeutralBandCancelChange() {
        var p = AppearancePolicy(delay: 4)
        XCTAssertNil(p.update(lux: 10, current: .light, now: 0))
        XCTAssertNil(p.update(lux: 60, current: .light, now: 2))
        XCTAssertNil(p.update(lux: 10, current: .light, now: 4))
        XCTAssertNil(p.update(lux: 10, current: .light, now: 6))
        XCTAssertEqual(p.update(lux: 10, current: .light, now: 8), .dark)
    }
    func testLightTransitionAndNoRepeat() {
        var p = AppearancePolicy(delay: 2)
        XCTAssertNil(p.update(lux: 100, current: .dark, now: 0))
        XCTAssertEqual(p.update(lux: 100, current: .dark, now: 2), .light)
        XCTAssertNil(p.update(lux: 100, current: .light, now: 4))
    }
    func testMissingAndInvalidSamplesCannotMeanDarkness() {
        for sample: Double? in [nil, -1, .nan, .infinity] {
            var p = AppearancePolicy(delay: 4)
            _ = p.update(lux: 1, current: .light, now: 0)
            XCTAssertNil(p.update(lux: sample, current: .light, now: 2))
            XCTAssertNil(p.update(lux: 1, current: .light, now: 4))
        }
    }
    func testSleepGapRestartsDelay() {
        var p = AppearancePolicy(delay: 4)
        _ = p.update(lux: 1, current: .light, now: 0)
        XCTAssertNil(p.update(lux: 1, current: .light, now: 100))
        XCTAssertNil(p.update(lux: 1, current: .light, now: 102))
        XCTAssertEqual(p.update(lux: 1, current: .light, now: 104), .dark)
    }
    func testBoundaryAndInvalidConfiguration() {
        var p = AppearancePolicy(delay: 0)
        XCTAssertNil(p.update(lux: 40, current: .light, now: 0))
        XCTAssertNil(p.update(lux: 80, current: .dark, now: 2))
        p.lightThreshold = 30
        XCTAssertNil(p.update(lux: 90, current: .dark, now: 4))
    }
}
