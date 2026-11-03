//
//  SiriToolTests.swift
//  DockFinderTests
//
//  What Siri AI can look up on its own: every station goes into Spotlight
//  (at most once a day), and stations keep their spoken names as keywords.
//

import CoreSpotlight
import Foundation
import Testing
@testable import DockFinder

@MainActor
struct SiriToolTests {
    private let stations = [
        info("a", "Mercer St & Bleecker St", 40.7268, -73.9966),
        info("b", "Smith St & Bergen St", 40.6861, -73.9906),
    ]

    @Test func indexesEveryStationThenWaitsADay() async {
        let temporary = TemporaryDefaults()
        var indexed: [[String]] = []
        func refresh(at now: Date) async -> Bool {
            await StationSpotlightIndex.refreshIfNeeded(
                now: now,
                defaults: temporary.defaults,
                directory: { stations },
                replace: { indexed.append($0.map(\.id)) }
            )
        }

        #expect(await refresh(at: referenceNow))
        #expect(indexed == [["a", "b"]])

        #expect(await refresh(at: referenceNow.addingTimeInterval(StationSpotlightIndex.refreshInterval - 60)) == false)
        #expect(indexed.count == 1)

        #expect(await refresh(at: referenceNow.addingTimeInterval(StationSpotlightIndex.refreshInterval)))
        #expect(indexed.count == 2)
    }

    @Test func retriesAfterAFailure() async {
        let temporary = TemporaryDefaults()
        let failed = await StationSpotlightIndex.refreshIfNeeded(
            now: referenceNow,
            defaults: temporary.defaults,
            directory: { throw DockFinderError.noStationData },
            replace: { _ in Issue.record("Nothing to index") }
        )
        #expect(failed == false)

        var indexed = false
        let retried = await StationSpotlightIndex.refreshIfNeeded(
            now: referenceNow.addingTimeInterval(60),
            defaults: temporary.defaults,
            directory: { stations },
            replace: { _ in indexed = true }
        )
        #expect(retried)
        #expect(indexed)
    }

    @Test func spokenStationNameIsAKeyword() {
        let keywords = StationEntity(id: "a", name: "Mercer St & Bleecker St").attributeSet.keywords ?? []
        #expect(keywords.contains("Mercer and Bleecker"))
        #expect(keywords.contains("Citi Bike"))
    }
}
