//
//  PlaceArrivalTests.swift
//  DockFinderTests
//
//  Alerts when arriving at a saved place without a ride: on every arrival
//  while the biking check is switched off (only on a bike when it's on),
//  not twice in an hour, and not on top of a ride or directions.
//

import CoreLocation
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

/// When a failed lookup is spoken, and whether a new geofence starts
/// out "inside".
struct PlaceArrivalFailureAndGeofenceRuleTests {
    private func ago(_ minutes: Double) -> Date {
        referenceNow.addingTimeInterval(-minutes * 60)
    }

    @Test func theFirstFailureIsSpoken() {
        #expect(PlaceArrivalRules.speaksFailure(spokenFailures: [], now: referenceNow))
    }

    @Test func notWithinThreeMinutesOfTheLastSpokenOne() {
        #expect(!PlaceArrivalRules.speaksFailure(spokenFailures: [ago(2.9)], now: referenceNow))
        #expect(PlaceArrivalRules.speaksFailure(spokenFailures: [ago(3)], now: referenceNow))
    }

    @Test func atMostThreeAnHour() {
        #expect(!PlaceArrivalRules.speaksFailure(spokenFailures: [ago(50), ago(30), ago(10)], now: referenceNow))
        #expect(PlaceArrivalRules.speaksFailure(spokenFailures: [ago(61), ago(30), ago(10)], now: referenceNow))
    }

    private let place = SavedPlace(name: "School", latitude: 40.7290, longitude: -73.9965, alertDistance: 500)

    private func fix(metersNorth: Double, minutesAgo: Double = 1, accuracy: Double = 10) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: place.latitude + metersNorth / 111_320, longitude: place.longitude),
            altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: -1,
            timestamp: referenceNow.addingTimeInterval(-minutesAgo * 60)
        )
    }

    @Test func startsInsideWhenARecentFixIsInTheCircle() {
        #expect(PlaceArrivalRules.startsInside(place, lastFix: fix(metersNorth: 400), now: referenceNow))
    }

    @Test func startsOutsideWhenTheFixIsOutsideTheCircle() {
        #expect(!PlaceArrivalRules.startsInside(place, lastFix: fix(metersNorth: 600), now: referenceNow))
    }

    @Test func startsOutsideWithoutARecentUsableFix() {
        #expect(!PlaceArrivalRules.startsInside(place, lastFix: nil, now: referenceNow))
        #expect(!PlaceArrivalRules.startsInside(place, lastFix: fix(metersNorth: 0, minutesAgo: 2.5), now: referenceNow))
        #expect(!PlaceArrivalRules.startsInside(place, lastFix: fix(metersNorth: 0, accuracy: -1), now: referenceNow))
    }
}

/// Arrivals start to finish, with the clock, motion, lookup, voice,
/// notifications and metrics faked: only a dock answer starts the
/// hour-long cooldown, and failures are spoken sparingly.
@MainActor
struct PlaceArrivalCooldownTests {
    private nonisolated static let answer = "Your usual dock has 8 docks open."
    private static let noSignal = String(localized: DockFinderError.networkUnavailable.localizedStringResource)

    private let place = SavedPlace(name: "School", latitude: 40.7290, longitude: -73.9965)
    private let defaults = UserDefaults(suiteName: "PlaceArrivalCooldownTests-\(UUID())")!

    /// Everything the monitor did, and the fake clock.
    private final class World {
        var now = referenceNow
        var spoken: [String] = []
        var quiet: [String] = []
        var logged: [(event: String, details: [String: String])] = []
        var lookupFails = true

        func advance(minutes: Double) { now = now.addingTimeInterval(minutes * 60) }
    }

    private func monitor(_ world: World, lookUp: @escaping @MainActor (SavedPlace) async throws -> String) -> PlaceArrivalMonitor {
        PlaceArrivalMonitor(
            defaults: defaults,
            now: { world.now },
            isBusy: { false },
            // Riding up, so these hold with the biking check on or off.
            wasCycling: { _ in true },
            lookUp: lookUp,
            announce: { text, _ in world.spoken.append(text) },
            notifyQuietly: { text, _ in world.quiet.append(text) },
            log: { world.logged.append(($0, $1)) }
        )
    }

    @Test(arguments: [DockFinderError.networkUnavailable, .locationUnavailable, .serviceUnavailable(statusCode: 503)])
    func aFailedLookupIsSpokenButDoesntStartTheCooldown(error: DockFinderError) async {
        let world = World()
        let monitor = monitor(world) { _ in throw error }
        await monitor.handleArrival(at: place)
        #expect(world.spoken == [String(localized: error.localizedStringResource)])
        #expect(monitor.lastAlert(for: place.id) == nil)
    }

    @Test func anUnexpectedFailureIsSpokenToo() async {
        let world = World()
        let monitor = monitor(world) { _ in throw CancellationError() }
        await monitor.handleArrival(at: place)
        #expect(world.spoken == [Self.noSignal])
        #expect(monitor.lastAlert(for: place.id) == nil)
    }

    @Test(arguments: [PlaceArrivalCooldownTests.answer, "No docks with space near School."])
    func aDockAnswerStartsTheCooldown(answer: String) async {
        let world = World()
        let monitor = monitor(world) { _ in answer }
        await monitor.handleArrival(at: place)
        #expect(world.spoken == [answer])
        #expect(monitor.lastAlert(for: place.id) == world.now)

        // Arriving again within the hour stays quiet; after it, alerts.
        world.advance(minutes: 59)
        await monitor.handleArrival(at: place)
        #expect(world.spoken == [answer])
        world.advance(minutes: 2)
        await monitor.handleArrival(at: place)
        #expect(world.spoken == [answer, answer])
    }

    @Test func anAnswerRightAfterAFailureIsSpokenAndStartsTheCooldown() async {
        let world = World()
        let monitor = monitor(world) { _ in
            if world.lookupFails { throw DockFinderError.networkUnavailable }
            return Self.answer
        }
        await monitor.handleArrival(at: place)
        world.lookupFails = false
        world.advance(minutes: 1)
        await monitor.handleArrival(at: place)
        #expect(world.spoken == [Self.noSignal, Self.answer])
        #expect(monitor.lastAlert(for: place.id) == world.now)
        #expect(monitor.spokenFailures(for: place.id).isEmpty)
    }

    @Test func anotherFailureWithinThreeMinutesIsOnlyAQuietNotification() async {
        let world = World()
        let monitor = monitor(world) { _ in throw DockFinderError.networkUnavailable }
        await monitor.handleArrival(at: place)
        world.advance(minutes: 2)
        await monitor.handleArrival(at: place)
        #expect(world.spoken == [Self.noSignal])
        #expect(world.quiet == [Self.noSignal])
        #expect(monitor.lastAlert(for: place.id) == nil)
    }

    @Test func aQuietFailureDoesntExtendTheWindow() async {
        let world = World()
        let monitor = monitor(world) { _ in throw DockFinderError.networkUnavailable }
        await monitor.handleArrival(at: place)      // 0:00 spoken
        world.advance(minutes: 2)
        await monitor.handleArrival(at: place)      // 2:00 quiet
        world.advance(minutes: 1.5)
        await monitor.handleArrival(at: place)      // 3:30, 3.5 min after the spoken one
        #expect(world.spoken == [Self.noSignal, Self.noSignal])
        #expect(world.quiet == [Self.noSignal])
    }

    @Test func atMostThreeSpokenFailuresAnHour() async {
        let world = World()
        let monitor = monitor(world) { _ in throw DockFinderError.networkUnavailable }
        for _ in 0..<4 {
            await monitor.handleArrival(at: place)  // 0, 4, 8, 12 minutes
            world.advance(minutes: 4)
        }
        #expect(world.spoken.count == 3)
        #expect(world.quiet.count == 1)
        // An hour after the first one, it's spoken again.
        world.now = referenceNow.addingTimeInterval(61 * 60)
        await monitor.handleArrival(at: place)
        #expect(world.spoken.count == 4)
    }

    @Test func theFailureLimitsSurviveARelaunch() async {
        let world = World()
        await monitor(world) { _ in throw DockFinderError.networkUnavailable }.handleArrival(at: place)
        world.advance(minutes: 1)
        // A new monitor on the same storage: iOS relaunched the app for the next event.
        await monitor(world) { _ in throw DockFinderError.networkUnavailable }.handleArrival(at: place)
        #expect(world.spoken == [Self.noSignal])
        #expect(world.quiet == [Self.noSignal])
    }

    @Test func eachFailureIsLoggedWithThePlaceIDNotItsName() async {
        let world = World()
        let monitor = monitor(world) { _ in throw DockFinderError.networkUnavailable }
        await monitor.handleArrival(at: place)
        world.advance(minutes: 1)
        await monitor.handleArrival(at: place)
        #expect(world.logged.map(\.event) == ["place_arrival_failed", "place_arrival_failed"])
        #expect(world.logged.map { $0.details["spoken"] } == ["yes", "no"])
        for entry in world.logged {
            #expect(entry.details["error"] == "networkUnavailable")
            #expect(entry.details["place_id"] == place.id.uuidString)
            #expect(!entry.details.values.contains(place.name))
        }
    }

    @Test func anAnswerLogsNoFailure() async {
        let world = World()
        await monitor(world) { _ in Self.answer }.handleArrival(at: place)
        #expect(world.logged.isEmpty)
    }

    @Test func aDuplicateCallDuringAnArrivalIsDropped() async {
        let world = World()
        var lookups = 0
        var release: CheckedContinuation<Void, Never>?
        let monitor = monitor(world) { _ in
            lookups += 1
            await withCheckedContinuation { release = $0 }
            return Self.answer
        }
        let first = Task { await monitor.handleArrival(at: place) }
        while release == nil { await Task.yield() }

        await monitor.handleArrival(at: place)
        #expect(lookups == 1)

        release?.resume()
        await first.value
        #expect(world.spoken == [Self.answer])
    }

    @Test func otherPlacesKeepTheirOwnRecords() async {
        let world = World()
        let gym = SavedPlace(name: "Gym", latitude: 40.74, longitude: -73.99)
        let monitor = monitor(world) { place in
            if place.name == "Gym" { throw DockFinderError.networkUnavailable }
            return Self.answer
        }
        await monitor.handleArrival(at: place)
        await monitor.handleArrival(at: gym)
        #expect(monitor.lastAlert(for: place.id) != nil)
        #expect(monitor.lastAlert(for: gym.id) == nil)
        #expect(monitor.spokenFailures(for: gym.id) == [world.now])
        #expect(monitor.spokenFailures(for: place.id).isEmpty)
    }

    private actor Counter {
        var count = 0
        func bump() { count += 1 }
    }

    @Test func motionIsCheckedOnlyWithTheBikingCheckOn() async {
        let world = World()
        let motionChecks = Counter()
        let monitor = PlaceArrivalMonitor(
            defaults: defaults, now: { world.now }, isBusy: { false },
            wasCycling: { _ in await motionChecks.bump(); return false },
            lookUp: { _ in Self.answer },
            announce: { text, _ in world.spoken.append(text) }, notifyQuietly: { _, _ in }, log: { _, _ in }
        )
        await monitor.handleArrival(at: place)
        #expect(await motionChecks.count == (PlaceArrivalRules.requiresCycling ? 1 : 0))
        #expect(world.spoken.count == (PlaceArrivalRules.requiresCycling ? 0 : 1))
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
