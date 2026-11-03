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

    /// What to say when the dock lookup fails, so an arrival is never
    /// silent. Anything that isn't a `DockFinderError` (in practice only a
    /// cancelled request) gets the "couldn't reach Citi Bike" line.
    static func failureMessage(for error: any Error) -> String {
        let known = error as? DockFinderError ?? .networkUnavailable
        return String(localized: known.localizedStringResource)
    }
}
