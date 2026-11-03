//
//  PlaceArrivalTests.swift
//  DockFinderTests
//
//  Alerts when arriving at a saved place without a ride: on every arrival
//  while the biking check is switched off (only on a bike when it's on),
//  not twice in an hour, and not on top of a ride or directions.
//

import Foundation
import Testing
@testable import DockFinder

struct PlaceArrivalRuleTests {
    typealias Sample = PlaceArrivalRules.ActivitySample

    private func ago(_ minutes: Double) -> Date {
        referenceNow.addingTimeInterval(-minutes * 60)
    }

    @Test func ridingUpCountsAsCycling() {
        let samples = [Sample(start: ago(40), cycling: false, confident: true), Sample(start: ago(18), cycling: true, confident: true)]
        #expect(PlaceArrivalRules.wasCycling(samples, now: referenceNow))
    }

    @Test func justGotOffTheBikeStillCounts() {
        let samples = [Sample(start: ago(4), cycling: true, confident: true), Sample(start: ago(1), cycling: false, confident: true)]
        #expect(PlaceArrivalRules.wasCycling(samples, now: referenceNow))
    }

    @Test func walkingAfterAnEarlierRideDoesnt() {
        let samples = [Sample(start: ago(50), cycling: true, confident: true), Sample(start: ago(30), cycling: false, confident: true)]
        #expect(!PlaceArrivalRules.wasCycling(samples, now: referenceNow))
    }

    @Test func lowConfidenceCyclingIsIgnored() {
        let samples = [Sample(start: ago(20), cycling: false, confident: true), Sample(start: ago(2), cycling: true, confident: false)]
        #expect(!PlaceArrivalRules.wasCycling(samples, now: referenceNow))
    }

    @Test func noActivityIsNotCycling() {
        #expect(!PlaceArrivalRules.wasCycling([], now: referenceNow))
    }

    /// With the biking check on (`requiresCycling: true`), as it was
    /// before every arrival alerted.
    private func shouldAlert(
        enabled: Bool = true,
        busy: Bool = false,
        lastAlert: Date? = nil,
        cycling: Bool? = true
    ) async -> Bool {
        await PlaceArrivalRules.shouldAlert(
            enabled: enabled, busyWithRideOrDirections: busy, lastAlert: lastAlert, now: referenceNow,
            requiresCycling: true, wasCycling: { cycling }
        )
    }

    @Test func alertsWhenBikingUp() async {
        #expect(await shouldAlert())
    }

    @Test func skipsWalkingAndTransit() async {
        #expect(await !shouldAlert(cycling: false))
    }

    @Test func alertsWhenMotionAccessIsOff() async {
        #expect(await shouldAlert(cycling: nil))
    }

    @Test func onceAnHourPerPlace() async {
        #expect(await !shouldAlert(lastAlert: ago(20)))
        #expect(await shouldAlert(lastAlert: ago(61)))
    }

    @Test func notWhenTurnedOffOrBusy() async {
        #expect(await !shouldAlert(enabled: false))
        #expect(await !shouldAlert(busy: true))
    }

    @Test func motionIsOnlyCheckedOnceTheOtherRulesPass() async {
        for (enabled, busy, lastAlert) in [(false, false, nil), (true, true, nil), (true, false, ago(20))] as [(Bool, Bool, Date?)] {
            let alerts = await PlaceArrivalRules.shouldAlert(
                enabled: enabled, busyWithRideOrDirections: busy, lastAlert: lastAlert, now: referenceNow,
                requiresCycling: true, wasCycling: { Issue.record("Motion was checked for an arrival that can't alert"); return true }
            )
            #expect(!alerts)
        }
    }
}

/// The biking check switched off (`PlaceArrivalRules.requiresCycling`):
/// every arrival alerts, and motion is never queried.
struct PlaceArrivalWithoutBikingCheckTests {
    private func shouldAlert(
        enabled: Bool = true,
        busy: Bool = false,
        lastAlert: Date? = nil,
        cycling: Bool?
    ) async -> Bool {
        await PlaceArrivalRules.shouldAlert(
            enabled: enabled, busyWithRideOrDirections: busy, lastAlert: lastAlert, now: referenceNow,
            requiresCycling: false, wasCycling: { cycling }
        )
    }

    @Test(arguments: [Bool?.none, false, true])
    func alertsHoweverTheRiderArrived(cycling: Bool?) async {
        #expect(await shouldAlert(cycling: cycling))
    }

    @Test func theDefaultIsTheSwitch() async {
        // Walking up: alerts exactly when the switch is off. Holds either
        // way, so flipping the switch needs no test changes.
        let alerts = await PlaceArrivalRules.shouldAlert(
            enabled: true, busyWithRideOrDirections: false, lastAlert: nil, now: referenceNow, wasCycling: { false }
        )
        #expect(alerts == !PlaceArrivalRules.requiresCycling)
    }

    @Test func neverChecksMotion() async {
        let alerts = await PlaceArrivalRules.shouldAlert(
            enabled: true, busyWithRideOrDirections: false, lastAlert: nil, now: referenceNow,
            requiresCycling: false, wasCycling: { Issue.record("Motion was checked with the biking check off"); return false }
        )
        #expect(alerts)
    }

    @Test(arguments: [Bool?.none, false, true])
    func keepsTheOtherRules(cycling: Bool?) async {
        #expect(await !shouldAlert(enabled: false, cycling: cycling))
        #expect(await !shouldAlert(busy: true, cycling: cycling))
        #expect(await !shouldAlert(lastAlert: referenceNow.addingTimeInterval(-20 * 60), cycling: cycling))
        #expect(await shouldAlert(lastAlert: referenceNow.addingTimeInterval(-61 * 60), cycling: cycling))
    }
}

struct PlaceArrivalFailureMessageTests {
    @Test func aDockFinderErrorSaysWhatWentWrong() {
        #expect(PlaceArrivalRules.failureMessage(for: DockFinderError.noAvailableDocks)
            == String(localized: DockFinderError.noAvailableDocks.localizedStringResource))
    }

    @Test func anythingElseStillSaysSomething() {
        #expect(PlaceArrivalRules.failureMessage(for: CancellationError())
            == String(localized: DockFinderError.networkUnavailable.localizedStringResource))
    }
}

struct SavedPlaceArrivalSettingTests {
    @Test func placesSavedBeforeThisSettingAlertByDefault() throws {
        let place = SavedPlace(name: "School", latitude: 40.7290, longitude: -73.9965)
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(place)) as? [String: Any])
        json.removeValue(forKey: "arrivalAlerts")
        let decoded = try JSONDecoder().decode(SavedPlace.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.arrivalAlerts)
    }

    @Test func turningItOffIsSaved() throws {
        var place = SavedPlace(name: "Gym", latitude: 0, longitude: 0)
        place.arrivalAlerts = false
        let decoded = try JSONDecoder().decode(SavedPlace.self, from: JSONEncoder().encode(place))
        #expect(!decoded.arrivalAlerts)
    }
}
