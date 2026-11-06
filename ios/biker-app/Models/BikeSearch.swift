//
//  BikeSearch.swift
//  Dock Finder
//
//  Finding a bike to ride away on, rather than a dock: the nearest station
//  with any bike, an e-bike, a classic bike, or only e-bikes.
//

import CoreLocation
import Foundation

/// Which bikes the rider is looking for.
nonisolated enum BikeKind: String, Sendable, Equatable, CaseIterable {
    /// Any bike, classic or electric.
    case any
    case ebike
    case classic
    /// A station whose bikes are all e-bikes (no classic bikes there).
    case ebikeOnly

    /// Whether a station with these bikes has what the rider wants.
    func matches(classic: Int, ebikes: Int) -> Bool {
        switch self {
        case .any: classic + ebikes > 0
        case .ebike: ebikes > 0
        case .classic: classic > 0
        case .ebikeOnly: ebikes > 0 && classic == 0
        }
    }

    /// Opens the answer: "The nearest e-bike is at West 15th and 6th, …".
    var leadIn: String {
        switch self {
        case .any: "The nearest bike is at"
        case .ebike: "The nearest e-bike is at"
        case .classic: "The nearest classic bike is at"
        case .ebikeOnly: "The nearest station with only e-bikes is"
        }
    }

    /// "There are no e-bikes near you right now."
    var noneNearby: String {
        switch self {
        case .any: "There are no bikes near you right now."
        case .ebike: "There are no e-bikes near you right now."
        case .classic: "There are no classic bikes near you right now."
        case .ebikeOnly: "There are no stations with only e-bikes near you right now."
        }
    }
}

nonisolated struct BikeSearchResult: Sendable, Equatable {
    let kind: BikeKind
    /// The nearest matching station, with its bike counts; `nil` when none
    /// is within reach.
    let station: DockStation?
    /// True when the user granted only approximate location.
    var locationIsApproximate = false

    /// "The nearest e-bike is at West 15th and 6th, 300 feet away. It has 3
    /// classic bikes and 2 e-bikes."
    var summary: String {
        guard let station else { return kind.noneNearby }
        var sentence = "\(kind.leadIn) \(station.spokenName), \(Speech.distance(station.straightLineDistance)). "
            + Speech.bikeCounts(classic: station.classicBikes ?? 0, ebikes: station.ebikes ?? 0)
        if locationIsApproximate {
            sentence += " Your location is approximate, so a closer one may exist."
        }
        return sentence
    }

    /// No `station` on purpose: Siri's follow-up offers directions to a dock
    /// with room, which is the wrong check for picking up a bike.
    var answer: DockAnswer { DockAnswer(text: summary) }
}

extension StationNetwork {
    /// Stations with the bikes the rider wants, nearest first (ties go to
    /// more bikes). Skips stations that aren't installed or haven't reported
    /// lately, whose counts can't be trusted.
    nonisolated func bikeStations(_ kind: BikeKind, around location: CLLocation) -> [DockStation] {
        stations
            .filter { station in
                guard station.isInstalled else { return false }
                if let reported = station.lastReported, now.timeIntervalSince(reported) > Self.maxStationReportAge {
                    return false
                }
                let classic = max(station.bikesAvailable - station.ebikesAvailable, 0)
                return kind.matches(classic: classic, ebikes: station.ebikesAvailable)
            }
            .map { DockStation(snapshot: $0, distance: location.distance(from: $0.location)) }
            .sorted {
                ($0.straightLineDistance, -(($0.classicBikes ?? 0) + ($0.ebikes ?? 0)))
                    < ($1.straightLineDistance, -(($1.classicBikes ?? 0) + ($1.ebikes ?? 0)))
            }
    }
}
