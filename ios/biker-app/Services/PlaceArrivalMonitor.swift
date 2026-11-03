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
//  Needs Always location access.
//

import CoreLocation
import CoreMotion
import Foundation
import UIKit

final class PlaceArrivalMonitor {
    static let shared = PlaceArrivalMonitor()

    private static let monitorName = "DockFinderSavedPlaces"
    private static let lastAlertsKey = "placeArrivalLastAlerts"

    private let announcer = Announcer()
    /// Shared so concurrent syncs never create two monitors with the same
    /// name, which iOS doesn't allow.
    private var monitorTask: Task<CLMonitor, Never>?
    private var eventsTask: Task<Void, Never>?
    /// Places whose arrival is being handled now, so a duplicate geofence
    /// event for the same place can't announce it twice.
    private var arrivalsInProgress: Set<UUID> = []

    /// Call at every launch, including the background relaunch iOS does
    /// for a geofence, and whenever saved places or permissions change.
    func sync() async {
        let monitor = await currentMonitor()
        let places = SavedPlacesStore.shared.places.filter(\.arrivalAlerts)
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
            // A new or moved place, or a new radius. Assume "outside" so
            // arriving triggers it.
            await monitor.add(
                CLMonitor.CircularGeographicCondition(center: place.location.coordinate, radius: place.alertDistance),
                identifier: identifier,
                assuming: .unsatisfied
            )
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
                    await self?.arrived(at: id)
                }
            } catch {}
        }
    }

    // MARK: - Arriving

    private func arrived(at placeID: UUID) async {
        guard let place = SavedPlacesStore.shared.place(id: placeID),
              arrivalsInProgress.insert(placeID).inserted
        else { return }
        defer { arrivalsInProgress.remove(placeID) }
        // Keep running while this fetches docks and speaks.
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Saved place arrival")
        defer { UIApplication.shared.endBackgroundTask(backgroundTask) }

        let now = Date.now
        let shouldAlert = await PlaceArrivalRules.shouldAlert(
            enabled: place.arrivalAlerts,
            busyWithRideOrDirections: RideTracker.shared.currentRide != nil || GuidanceSession.shared.isActive,
            lastAlert: Self.lastAlerts()[placeID.uuidString],
            now: now,
            wasCycling: { await MotionCheck.wasCycling(now: now) }
        )
        guard shouldAlert else { return }

        var text: String
        do {
            let answer = try await DockFinderService.live.findDock(for: place).answer
            text = answer.text
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
        } catch {
            text = PlaceArrivalRules.failureMessage(for: error)
        }
        await announcer.announce(text, title: "Arriving at \(place.name)")
        // Only now: an arrival that never got announced (the app was
        // stopped mid-lookup, say) shouldn't silence this place for an hour.
        Self.recordAlert(for: placeID, at: .now)
    }

    private static func recordAlert(for placeID: UUID, at date: Date) {
        // Read again rather than reusing an earlier copy, so another
        // place's alert recorded meanwhile isn't overwritten.
        var lastAlerts = lastAlerts()
        lastAlerts[placeID.uuidString] = date
        UserDefaults.standard.set(lastAlerts, forKey: lastAlertsKey)
    }

    private static func lastAlerts() -> [String: Date] {
        UserDefaults.standard.dictionary(forKey: lastAlertsKey) as? [String: Date] ?? [:]
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
