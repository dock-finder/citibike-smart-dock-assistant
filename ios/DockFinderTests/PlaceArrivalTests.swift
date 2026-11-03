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

/// One arrival, start to finish, with the lookup and the voice faked:
/// only a dock answer starts the hour-long cooldown.
@MainActor
struct PlaceArrivalCooldownTests {
    private let place = SavedPlace(name: "School", latitude: 40.7290, longitude: -73.9965)
    private let defaults = UserDefaults(suiteName: "PlaceArrivalCooldownTests-\(UUID())")!

    private final class Spoken {
        var lines: [String] = []
    }

    private func monitor(_ spoken: Spoken, lookUp: @escaping @MainActor (SavedPlace) async throws -> String) -> PlaceArrivalMonitor {
        PlaceArrivalMonitor(defaults: defaults, isBusy: { false }, lookUp: lookUp, announce: { text, _ in spoken.lines.append(text) })
    }

    @Test(arguments: [DockFinderError.networkUnavailable, .locationUnavailable, .serviceUnavailable(statusCode: 503)])
    func aFailedLookupIsSpokenButDoesntStartTheCooldown(error: DockFinderError) async {
        let spoken = Spoken()
        let monitor = monitor(spoken) { _ in throw error }
        await monitor.handleArrival(at: place)
        #expect(spoken.lines == [String(localized: error.localizedStringResource)])
        #expect(monitor.lastAlert(for: place.id) == nil)

        // Arriving again straight away tries again.
        await monitor.handleArrival(at: place)
        #expect(spoken.lines.count == 2)
    }

    @Test func anUnexpectedFailureIsSpokenToo() async {
        let spoken = Spoken()
        let monitor = monitor(spoken) { _ in throw CancellationError() }
        await monitor.handleArrival(at: place)
        #expect(spoken.lines == [String(localized: DockFinderError.networkUnavailable.localizedStringResource)])
        #expect(monitor.lastAlert(for: place.id) == nil)
    }

    @Test(arguments: ["Your usual dock has 8 docks open.", "No docks with space near School."])
    func aDockAnswerStartsTheCooldown(answer: String) async {
        let spoken = Spoken()
        let monitor = monitor(spoken) { _ in answer }
        await monitor.handleArrival(at: place)
        #expect(spoken.lines == [answer])
        #expect(monitor.lastAlert(for: place.id) != nil)

        // Arriving again within the hour stays quiet.
        await monitor.handleArrival(at: place)
        #expect(spoken.lines == [answer])
    }

    @Test func anAnswerAfterAFailureStartsTheCooldown() async {
        let spoken = Spoken()
        var failsNext = true
        let monitor = monitor(spoken) { _ in
            if failsNext {
                failsNext = false
                throw DockFinderError.networkUnavailable
            }
            return "Your usual dock has 8 docks open."
        }
        for _ in 0..<3 {
            await monitor.handleArrival(at: place)
        }
        #expect(spoken.lines == [
            String(localized: DockFinderError.networkUnavailable.localizedStringResource),
            "Your usual dock has 8 docks open.",
        ])
    }

    @Test func aDuplicateEventDuringAnArrivalIsDropped() async {
        let spoken = Spoken()
        var lookups = 0
        var release: CheckedContinuation<Void, Never>?
        let monitor = monitor(spoken) { _ in
            lookups += 1
            await withCheckedContinuation { release = $0 }
            return "Your usual dock has 8 docks open."
        }
        let first = Task { await monitor.handleArrival(at: place) }
        while release == nil { await Task.yield() }

        await monitor.handleArrival(at: place)
        #expect(lookups == 1)

        release?.resume()
        await first.value
        #expect(spoken.lines == ["Your usual dock has 8 docks open."])
    }

    @Test func otherPlacesKeepTheirCooldown() async {
        let spoken = Spoken()
        let gym = SavedPlace(name: "Gym", latitude: 40.74, longitude: -73.99)
        let monitor = monitor(spoken) { _ in "Your usual dock has 8 docks open." }
        await monitor.handleArrival(at: place)
        await monitor.handleArrival(at: gym)
        #expect(monitor.lastAlert(for: place.id) != nil)
        #expect(monitor.lastAlert(for: gym.id) != nil)
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
