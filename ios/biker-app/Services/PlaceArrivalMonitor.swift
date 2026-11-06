//
//  PlaceArrivalMonitor.swift
//  Dock Finder
//
//  Tells the rider where to dock when they bike up to a saved place, even
//  if they never started a ride. iOS watches a circle (geofence) around
//  each saved place at its alert distance and wakes Dock Finder when the
//  rider crosses into one, even if the app wasn't running. The app then
//  speaks the dock answer and posts it as a notification, however the
//  rider arrived. (A check that they were biking, not walking or on the
//  subway, is switched off: see PlaceArrivalRules.requiresCycling.)
//
//  Needs Always location access, and a service session that says so (see
//  updateServiceSession): without one, iOS treats the geofences as While
//  Using and holds arrivals until the app next runs.
//

import CoreLocation
import CoreMotion
import Foundation
import UIKit

final class PlaceArrivalMonitor {
    static let shared = PlaceArrivalMonitor()

    private static let monitorName = "DockFinderSavedPlaces"
    private static let lastAlertsKey = "placeArrivalLastAlerts"
    /// Per place, when failed lookups were spoken in the last hour. Saved,
    /// because each arrival may be a fresh background launch.
    private static let spokenFailuresKey = "placeArrivalSpokenFailures"

    private let defaults: UserDefaults
    private let now: @MainActor () -> Date
    private let isBusy: @MainActor () -> Bool
    private let wasCycling: @Sendable (Date) async -> Bool?
    private let lookUp: @MainActor (SavedPlace) async throws -> String
    private let announce: @MainActor (_ text: String, _ title: String) async -> Void
    private let notifyQuietly: @MainActor (_ text: String, _ title: String) async -> Void
    private let log: @MainActor (_ event: String, _ details: [String: String]) -> Void
    /// Shared so concurrent syncs never create two monitors with the same
    /// name, which iOS doesn't allow.
    private var monitorTask: Task<CLMonitor, Never>?
    private var eventsTask: Task<Void, Never>?
    /// Held while any place has arrival alerts and Always is granted.
    private var serviceSession: CLServiceSession?
    /// Places whose arrival is being handled now. iOS's events are handled
    /// one at a time, so this only matters if handleArrival is ever called
    /// from somewhere else too.
    private var arrivalsInProgress: Set<UUID> = []

    /// The parameters are for tests; the app uses the real clock, ride,
    /// motion, dock lookup, voice and metrics.
    init(
        defaults: UserDefaults = .standard,
        now: (@MainActor () -> Date)? = nil,
        isBusy: (@MainActor () -> Bool)? = nil,
        wasCycling: (@Sendable (Date) async -> Bool?)? = nil,
        lookUp: (@MainActor (SavedPlace) async throws -> String)? = nil,
        announce: (@MainActor (_ text: String, _ title: String) async -> Void)? = nil,
        notifyQuietly: (@MainActor (_ text: String, _ title: String) async -> Void)? = nil,
        log: (@MainActor (_ event: String, _ details: [String: String]) -> Void)? = nil
    ) {
        self.defaults = defaults
        self.now = now ?? { .now }
        self.isBusy = isBusy ?? { RideTracker.shared.currentRide != nil || GuidanceSession.shared.isActive }
        self.wasCycling = wasCycling ?? { await MotionCheck.wasCycling(now: $0) }
        self.lookUp = lookUp ?? { try await Self.liveAnswer(for: $0) }
        self.log = log ?? { Metrics.shared.log($0, details: $1) }
        let announcer = announce == nil || notifyQuietly == nil ? Announcer() : nil
        self.announce = announce ?? { await announcer?.announce($0, title: $1) }
        self.notifyQuietly = notifyQuietly ?? { await announcer?.notifyQuietly($0, title: $1) }
    }

    /// Call at every launch, including the background relaunch iOS does
    /// for a geofence, and whenever saved places or permissions change.
    func sync() async {
        let places = SavedPlacesStore.shared.places.filter(\.arrivalAlerts)
        // First, so it's in place before any arrival is handed over.
        updateServiceSession(watching: !places.isEmpty)
        let monitor = await currentMonitor()
        let wanted = Set(places.map(\.id.uuidString))

        for identifier in await monitor.identifiers where !wanted.contains(identifier) {
            await monitor.remove(identifier)
        }
        for place in places {
            let identifier = place.id.uuidString
            if let record = await monitor.record(for: identifier),
               let existing = record.condition as? CLMonitor.CircularGeographicCondition,
               PlaceArrivalRules.geofenceIsCurrent(center: existing.center, radius: existing.radius, for: place) {
                continue
            }
            // A new or moved place, a new radius, or the alert just turned
            // on. Starts "outside" so arriving triggers it, unless the
            // rider is standing in the circle right now.
            let inside = PlaceArrivalRules.startsInside(place, lastFix: LocationService.shared.lastKnownLocation, now: now())
            await monitor.add(
                CLMonitor.CircularGeographicCondition(center: place.location.coordinate, radius: place.alertDistance),
                identifier: identifier,
                assuming: inside ? .satisfied : .unsatisfied
            )
        }
    }

    /// Core Location treats a monitor's events as While Using unless the app
    /// holds a session requiring Always; then it holds arrivals until the app
    /// runs again, instead of waking it. Apple's rule is to create the session
    /// at every launch, including background relaunches, which sync() is
    /// called for. Only with Always granted, so it never prompts.
    private func updateServiceSession(watching: Bool) {
        if watching, LocationService.shared.authorizationStatus == .authorizedAlways {
            if serviceSession == nil {
                serviceSession = CLServiceSession(authorization: .always)
            }
        } else {
            serviceSession?.invalidate()
            serviceSession = nil
        }
    }

    private func currentMonitor() async -> CLMonitor {
        if let monitorTask { return await monitorTask.value }
        let task = Task { () -> CLMonitor in
            let monitor = await CLMonitor(Self.monitorName)
            self.listen(to: monitor)
            return monitor
        }
        monitorTask = task
        return await task.value
    }

    private func listen(to monitor: CLMonitor) {
        eventsTask = Task { [weak self] in
            do {
                for try await event in await monitor.events where event.state == .satisfied {
                    guard let id = UUID(uuidString: event.identifier) else { continue }
                    await self?.arrived(at: id, occurredAt: event.date)
                }
            } catch {}
        }
    }

    // MARK: - Arriving

    private func arrived(at placeID: UUID, occurredAt: Date) async {
        guard let place = SavedPlacesStore.shared.place(id: placeID) else { return }
        // Keep running while this fetches docks and speaks.
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Saved place arrival")
        defer { UIApplication.shared.endBackgroundTask(backgroundTask) }
        await handleArrival(at: place, occurredAt: occurredAt)
    }

    /// Alerts for an arrival at `place` if the rules allow it. Only a dock
    /// answer (including "No docks with space near…") starts the place's
    /// hour-long cooldown. A failed lookup doesn't, so the next arrival
    /// tries again (a repeat beats a missed answer); see reportFailure for
    /// when a failure is spoken.
    /// - Parameter occurredAt: When iOS saw the rider cross into the circle.
    ///   An arrival handed over more than a few minutes after that is only
    ///   logged (see PlaceArrivalRules.maxArrivalDelay).
    func handleArrival(at place: SavedPlace, occurredAt: Date? = nil) async {
        guard arrivalsInProgress.insert(place.id).inserted else { return }
        defer { arrivalsInProgress.remove(place.id) }

        let now = self.now()
        let cycling = self.wasCycling
        let shouldAlert = await PlaceArrivalRules.shouldAlert(
            enabled: place.arrivalAlerts,
            busyWithRideOrDirections: isBusy(),
            lastAlert: lastAlert(for: place.id),
            now: now,
            wasCycling: { await cycling(now) }
        )
        guard shouldAlert else { return }

        if PlaceArrivalRules.isStale(occurredAt: occurredAt, now: now), let occurredAt {
            // Shows in the usage sheet how often iOS woke the app too late.
            log("place_arrival_late", [
                "place_id": place.id.uuidString,
                "delay_s": String(Int(now.timeIntervalSince(occurredAt))),
            ])
            return
        }

        let title = "Arriving at \(place.name)"
        let text: String
        do {
            text = try await lookUp(place)
        } catch {
            await reportFailure(error, at: place, title: title)
            return
        }
        await announce(text, title)
        // Only once the answer was given, so an arrival cut off mid-lookup
        // doesn't silence the place either.
        recordAlert(for: place.id, at: self.now())
        setSpokenFailures([], for: place.id)
    }

    /// Speaks why the lookup failed, unless one was spoken for this place
    /// in the last few minutes or three already were this hour: then it's
    /// only posted as a quiet notification. Either way the place stays
    /// ready to alert again, and the failure is logged.
    private func reportFailure(_ error: any Error, at place: SavedPlace, title: String) async {
        let now = self.now()
        let earlier = spokenFailures(for: place.id)
        let speaks = PlaceArrivalRules.speaksFailure(spokenFailures: earlier, now: now)
        var details = Metrics.errorDetails(error)
        details["place_id"] = place.id.uuidString
        details["spoken"] = speaks ? "yes" : "no"
        log("place_arrival_failed", details)

        let text = PlaceArrivalRules.failureMessage(for: error)
        guard speaks else {
            await notifyQuietly(text, title)
            return
        }
        await announce(text, title)
        setSpokenFailures(earlier + [now], for: place.id)
    }

    /// The dock answer for `place`, logged and offered for directions.
    private static func liveAnswer(for place: SavedPlace) async throws -> String {
        let answer = try await DockFinderService.live.findDock(for: place).answer
        var text = answer.text
        let here = LocationService.shared.lastKnownLocation
        Metrics.shared.log(
            "place_arrival_alert",
            station: answer.station?.name,
            avoidedStation: answer.avoided?.name,
            location: here,
            details: ["place": place.name, "answer": answer.text]
        )
        SavingsStore.shared.record(answer, from: here, context: "place_arrival")
        SavingsStore.shared.recordHandsFree(context: "place_arrival")
        if let station = answer.station {
            GuidanceSession.shared.offer(station)
            text += " For directions, say: Hey Siri, ask Dock Finder to direct me."
        }
        return text
    }

    /// When the place last got a dock answer (its cooldown's start), if ever.
    func lastAlert(for placeID: UUID) -> Date? {
        lastAlerts()[placeID.uuidString]
    }

    /// When failed lookups for the place were spoken in the last hour.
    func spokenFailures(for placeID: UUID) -> [Date] {
        let all = defaults.dictionary(forKey: Self.spokenFailuresKey) as? [String: [Date]] ?? [:]
        return all[placeID.uuidString] ?? []
    }

    private func setSpokenFailures(_ dates: [Date], for placeID: UUID) {
        // Read again rather than reusing an earlier copy, so other places'
        // entries recorded meanwhile aren't overwritten.
        var all = defaults.dictionary(forKey: Self.spokenFailuresKey) as? [String: [Date]] ?? [:]
        let now = self.now()
        let recent = dates.filter { now.timeIntervalSince($0) < PlaceArrivalRules.cooldown }
        all[placeID.uuidString] = recent.isEmpty ? nil : recent
        defaults.set(all, forKey: Self.spokenFailuresKey)
    }

    private func recordAlert(for placeID: UUID, at date: Date) {
        var lastAlerts = lastAlerts()
        lastAlerts[placeID.uuidString] = date
        defaults.set(lastAlerts, forKey: Self.lastAlertsKey)
    }

    private func lastAlerts() -> [String: Date] {
        defaults.dictionary(forKey: Self.lastAlertsKey) as? [String: Date] ?? [:]
    }
}

/// Whether the rider is on a bike, from the phone's motion coprocessor.
/// Arrival alerts only ask when PlaceArrivalRules.requiresCycling is on.
nonisolated enum MotionCheck {
    /// `nil` when iOS can't say: no motion hardware, or Motion & Fitness
    /// access is off.
    static func wasCycling(now: Date) async -> Bool? {
        guard CMMotionActivityManager.isActivityAvailable() else { return nil }
        switch CMMotionActivityManager.authorizationStatus() {
        case .denied, .restricted: return nil
        default: break
        }
        let manager = CMMotionActivityManager()
        let from = now.addingTimeInterval(-PlaceArrivalRules.activityLookback)
        return await withCheckedContinuation { continuation in
            manager.queryActivityStarting(from: from, to: now, to: .main) { activities, error in
                withExtendedLifetime(manager) {}
                guard let activities, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let samples = activities.map {
                    PlaceArrivalRules.ActivitySample(start: $0.startDate, cycling: $0.cycling, confident: $0.confidence != .low)
                }
                continuation.resume(returning: PlaceArrivalRules.wasCycling(samples, now: now))
            }
        }
    }

    /// Shows the Motion & Fitness prompt, if it hasn't been answered yet.
    /// Call while the app is on screen.
    static func requestPermission() async {
        guard CMMotionActivityManager.authorizationStatus() == .notDetermined else { return }
        _ = await wasCycling(now: .now)
    }
}
