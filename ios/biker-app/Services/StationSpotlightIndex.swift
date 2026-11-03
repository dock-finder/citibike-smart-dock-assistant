//
//  StationSpotlightIndex.swift
//  Dock Finder
//
//  Puts every Citi Bike station in Spotlight, so Siri (with the Siri AI
//  Developer Preview) can find the station a rider means however they
//  describe it. Stations rarely change, so the index is rebuilt at most
//  once a day, when the app comes to the foreground.
//

import AppIntents
import CoreSpotlight
import Foundation

enum StationSpotlightIndex {
    static let refreshInterval: TimeInterval = 24 * 60 * 60
    private static let lastIndexedKey = "stationsIndexedAt"

    /// Rebuilds the index unless it was rebuilt within `refreshInterval`.
    /// Returns whether it did. A failure is retried next time.
    @discardableResult
    static func refreshIfNeeded(
        now: Date = .now,
        defaults: UserDefaults = .standard,
        directory: () async throws -> [StationInformation] = { try await DockFinderService.live.stationDirectory() },
        replace: ([StationEntity]) async throws -> Void = replaceInSpotlight
    ) async -> Bool {
        if let last = defaults.object(forKey: lastIndexedKey) as? Date,
           now.timeIntervalSince(last) < refreshInterval {
            return false
        }
        do {
            let stations = try await directory()
            guard !stations.isEmpty else { return false }
            try await replace(stations.map(StationEntity.init))
            defaults.set(now, forKey: lastIndexedKey)
            return true
        } catch {
            return false
        }
    }

    /// Drops stations that were removed from the system, then indexes the rest.
    static func replaceInSpotlight(_ stations: [StationEntity]) async throws {
        let index = CSSearchableIndex.default()
        try await index.deleteAppEntities(ofType: StationEntity.self)
        try await index.indexAppEntities(stations)
    }
}
