//
//  PlaceArrival.swift
//  Dock Finder
//
//  When arriving at a saved place should trigger a "where to dock" alert,
//  without a ride having been started. PlaceArrivalMonitor applies these
//  rules to geofence events; they're plain logic so they can be tested.
//

import CoreLocation
import Foundation

nonisolated enum PlaceArrivalRules {
    /// Whether an arrival only alerts when the rider was biking (the motion
    /// check below). Off: every arrival alerts, however the rider got there,
    /// because a false alert costs less than a missed one. Set to `true` to
    /// go back to skipping walking and the subway; the motion check, its
    /// tests and the Motion & Fitness prompt are all still in place.
    static let requiresCycling = false

    /// At most one alert per place in this long, so circling the block or
    /// a GPS wobble at the geofence's edge doesn't repeat it.
    static let cooldown: TimeInterval = 60 * 60
    /// How far back to look at motion activity.
    static let activityLookback: TimeInterval = 60 * 60
    /// Cycling that started this recently counts even if iOS has already
    /// switched to "walking" (it lags behind getting off the bike).
    static let recentCyclingWindow: TimeInterval = 5 * 60
    /// A failed lookup doesn't start the cooldown, so after one is spoken,
    /// more failures at that place stay quiet this long (a dead zone, or
    /// wobbling at the circle's edge). An answer is still spoken.
    static let failureQuietPeriod: TimeInterval = 3 * 60
    /// And at most this many are spoken per place in an hour (a long Citi
    /// Bike outage).
    static let maxSpokenFailuresPerHour = 3
    /// A location fix this recent decides whether the rider is already
    /// inside a geofence that's being added.
    static let insideCheckMaxAge: TimeInterval = 2 * 60
    /// An arrival iOS hands over later than this (because the app wasn't
    /// woken in time) isn't news any more: the rider has docked or moved on.
    /// It's logged, not spoken, so it can't talk over a later request.
    static let maxArrivalDelay: TimeInterval = 5 * 60

    /// True when an arrival that happened at `occurredAt` is too old to speak.
    static func isStale(occurredAt: Date?, now: Date) -> Bool {
        guard let occurredAt else { return false }
        return now.timeIntervalSince(occurredAt) > maxArrivalDelay
    }

    /// One reading from the phone's motion coprocessor.
    nonisolated struct ActivitySample: Sendable, Equatable {
        let start: Date
        let cycling: Bool
        /// Medium or high confidence.
        let confident: Bool
    }

    /// True when the rider is biking: the latest confident activity is
    /// cycling, or cycling started in the last few minutes.
    static func wasCycling(_ samples: [ActivitySample], now: Date) -> Bool {
        let confident = samples.filter(\.confident).sorted { $0.start < $1.start }
        if confident.last?.cycling == true { return true }
        return confident.contains { $0.cycling && now.timeIntervalSince($0.start) <= recentCyclingWindow }
    }

    /// True when iOS is already watching this exact circle for `place`, so
    /// `PlaceArrivalMonitor.sync` can leave it alone. A place moved on the
    /// map or given a new alert radius gets its geofence replaced.
    static func geofenceIsCurrent(center: CLLocationCoordinate2D, radius: CLLocationDistance, for place: SavedPlace) -> Bool {
        center.latitude == place.latitude && center.longitude == place.longitude && radius == place.alertDistance
    }

    /// Cheap checks first; motion is only queried (through `wasCycling`)
    /// when `requiresCycling` is on and everything else already passed.
    /// - Parameter wasCycling: `nil` when iOS can't tell (no motion
    ///   permission). Then the alert isn't filtered, rather than never firing.
    static func shouldAlert(
        enabled: Bool,
        busyWithRideOrDirections: Bool,
        lastAlert: Date?,
        now: Date,
        requiresCycling: Bool = PlaceArrivalRules.requiresCycling,
        wasCycling: @Sendable () async -> Bool?
    ) async -> Bool {
        guard enabled, !busyWithRideOrDirections else { return false }
        if let lastAlert, now.timeIntervalSince(lastAlert) < cooldown { return false }
        guard requiresCycling else { return true }
        return await wasCycling() != false
    }

    /// Whether a failed lookup is spoken, given when this place's failures
    /// were spoken before. Not within `failureQuietPeriod` of the last one,
    /// and not more than `maxSpokenFailuresPerHour` in an hour.
    static func speaksFailure(spokenFailures: [Date], now: Date) -> Bool {
        let lastHour = spokenFailures.filter { now.timeIntervalSince($0) < cooldown }
        if let last = lastHour.max(), now.timeIntervalSince(last) < failureQuietPeriod { return false }
        return lastHour.count < maxSpokenFailuresPerHour
    }

    /// Whether a geofence being added for `place` should start out as
    /// "inside": a fix from the last couple of minutes puts the rider in
    /// the circle. Then saving, moving or enlarging a place, or turning its
    /// alert on, while standing there doesn't alert straight away; leaving
    /// and coming back does. With no recent fix it starts "outside", so the
    /// next time iOS sees the rider inside, it alerts.
    static func startsInside(_ place: SavedPlace, lastFix: CLLocation?, now: Date) -> Bool {
        guard let lastFix, lastFix.horizontalAccuracy >= 0,
              now.timeIntervalSince(lastFix.timestamp) <= insideCheckMaxAge
        else { return false }
        return lastFix.distance(from: place.location) <= place.alertDistance
    }

    /// What to say when the dock lookup fails, so an arrival is never
    /// silent. Anything that isn't a `DockFinderError` (in practice only a
    /// cancelled request) gets the "couldn't reach Citi Bike" line.
    static func failureMessage(for error: any Error) -> String {
        let known = error as? DockFinderError ?? .networkUnavailable
        return String(localized: known.localizedStringResource)
    }
}
