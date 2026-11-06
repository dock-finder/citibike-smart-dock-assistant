//
//  BikeSearchTests.swift
//  DockFinderTests
//
//  Finding a bike to ride away on: which requests mean it, which station
//  answers it, and what's said.
//

import CoreLocation
import Foundation
import Testing
@testable import DockFinder

struct BikeRequestParsingTests {
    @Test(arguments: [
        ("what's the nearest bike", ParsedRequest.nearestBike(.any)),
        ("Where can I get a bike near me?", .nearestBike(.any)),
        ("any bikes nearby", .nearestBike(.any)),
        ("find me a Citi Bike", .nearestBike(.any)),
        ("nearest e-bike", .nearestBike(.ebike)),
        ("where's an ebike", .nearestBike(.ebike)),
        ("is there an electric bike near me", .nearestBike(.ebike)),
        ("what's the nearest station with an e bike", .nearestBike(.ebike)),
        ("nearest classic bike", .nearestBike(.classic)),
        ("where can I get a regular bike", .nearestBike(.classic)),
        ("what's the nearest station that only has e-bikes", .nearestBike(.ebikeOnly)),
        ("nearest e-bike only station", .nearestBike(.ebikeOnly)),
        ("find a station with no classic bikes", .nearestBike(.ebikeOnly)),
    ])
    func understandsBikeRequests(request: String, expected: ParsedRequest) {
        #expect(KeywordRequestParser.parse(request) == expected)
    }

    /// Wordings that meant something before bike search keep that meaning.
    @Test(arguments: [
        ("How many bikes are out?", ParsedRequest.citywide),
        ("how many bikes are available", .citywide),
        ("does Mercer and Bleecker have bikes", .station("mercer and bleecker")),
        ("how many bikes at West 15th and 6th", .station("west 15th and 6th")),
        ("bike to school", .startRide("school")),
        ("find me a bike dock", .nearMe),
        ("where can I return my bike", .nearMe),
        ("find a dock", .nearMe),
        ("is there a bike near Union Square", .place("union square")),
    ])
    func keepsEarlierMeanings(request: String, expected: ParsedRequest) {
        #expect(KeywordRequestParser.parse(request) == expected)
    }

    @Test(arguments: ["end my bike ride", "stop my bike ride"])
    func ridesAreNotBikeSearches(request: String) {
        #expect(KeywordRequestParser.parse(request)?.isBikeSearch != true)
    }
}

struct BikeSearchTests {
    // Distances from the rider (at `near`): near ≈ 0 m, mid ≈ 450 m, far ≈ 1.2 km.
    let near = info("near", "Smith St & Bergen St", 40.6861, -73.9906)
    let mid = info("mid", "Court St & State St", 40.6900, -73.9920)
    let far = info("far", "Atlantic Ave & Fort Greene Pl", 40.6840, -73.9765)

    private func network(_ statuses: [StationStatus]) throws -> StationNetwork {
        try StationNetwork(information: informationFeed([near, mid, far]), status: statusFeed(statuses), now: referenceNow)
    }

    /// Near: 2 classic bikes. Mid: 3 e-bikes only. Far: 4 classic and 1 e-bike.
    private func mixed() throws -> StationNetwork {
        try network([
            status("near", docks: 5, bikes: 2, ebikes: 0),
            status("mid", docks: 5, bikes: 3, ebikes: 3),
            status("far", docks: 5, bikes: 5, ebikes: 1),
        ])
    }

    @Test(arguments: [
        (BikeKind.any, "near"),
        (.classic, "near"),
        (.ebike, "mid"),
        (.ebikeOnly, "mid"),
    ])
    func picksTheNearestStationWithThoseBikes(kind: BikeKind, expected: String) throws {
        let result = try DockFinderService.nearestBike(kind, to: userLocation, in: try mixed())
        #expect(result.station?.id == expected)
    }

    @Test func aStationWithBothKindsIsNotEbikeOnly() throws {
        let result = try DockFinderService.nearestBike(.ebikeOnly, to: userLocation, in: try network([
            status("near", docks: 5, bikes: 0),
            status("mid", docks: 5, bikes: 0),
            status("far", docks: 5, bikes: 5, ebikes: 1),
        ]))
        #expect(result.station == nil)
        #expect(result.summary == "There are no stations with only e-bikes near you right now.")
    }

    @Test func stationsThatArentReportingOrInstalledAreSkipped() throws {
        let result = try DockFinderService.nearestBike(.any, to: userLocation, in: try network([
            status("near", docks: 5, bikes: 4, reported: referenceNow.addingTimeInterval(-2 * 60 * 60)),
            status("mid", docks: 5, bikes: 4, installed: false),
            status("far", docks: 5, bikes: 1),
        ]))
        #expect(result.station?.id == "far")
    }

    @Test func noneNearbyIsSaid() throws {
        let result = try DockFinderService.nearestBike(.ebike, to: userLocation, in: try network([
            status("near", docks: 5, bikes: 2),
            status("mid", docks: 5, bikes: 1),
            status("far", docks: 5, bikes: 0),
        ]))
        #expect(result.answer.text == "There are no e-bikes near you right now.")
    }

    @Test func outsideTheServiceAreaThrows() throws {
        let boston = CLLocation(latitude: 42.3601, longitude: -71.0589)
        #expect(throws: DockFinderError.outsideServiceArea) {
            try DockFinderService.nearestBike(.any, to: boston, in: try mixed())
        }
    }

    @Test func theAnswerNamesTheStationAndItsBikes() throws {
        let ebike = try DockFinderService.nearestBike(.ebike, to: userLocation, in: try mixed())
        #expect(ebike.summary.hasPrefix("The nearest e-bike is at Court and State, "))
        #expect(ebike.summary.hasSuffix(" away. It has no classic bikes and 3 e-bikes."))

        let any = try DockFinderService.nearestBike(.any, to: userLocation, in: try mixed())
        #expect(any.summary == "The nearest bike is at Smith and Bergen, right there. It has 2 classic bikes and no e-bikes.")

        let only = try DockFinderService.nearestBike(.ebikeOnly, to: userLocation, in: try mixed())
        #expect(only.summary.hasPrefix("The nearest station with only e-bikes is Court and State, "))
    }

    @Test func bikeAnswersDontOfferDockDirections() throws {
        let result = try DockFinderService.nearestBike(.any, to: userLocation, in: try mixed())
        #expect(result.answer.station == nil)
    }

    @Test func approximateLocationIsMentioned() throws {
        let result = try DockFinderService.nearestBike(.any, to: userLocation, in: try mixed(), locationIsApproximate: true)
        #expect(result.summary.hasSuffix(" Your location is approximate, so a closer one may exist."))
    }
}

private struct ModelReading: RequestParsing {
    var result: ParsedRequest?
    var answerSource: DockAnswer.Source { .onDeviceModel }
    func parse(_ text: String) async -> ParsedRequest? { result }
}

@MainActor
struct BikeRoutingTests {
    let near = info("near", "Smith St & Bergen St", 40.6861, -73.9906)
    let mid = info("mid", "Court St & State St", 40.6900, -73.9920)

    private func router(model: ParsedRequest?) -> AssistantRouter {
        AssistantRouter(
            service: DockFinderService(
                location: StubLocation(result: .success(LocationFix(location: userLocation, isApproximate: false))),
                feeds: StubFeeds(
                    information: .success(informationFeed([near, mid])),
                    status: .success(statusFeed([status("near", docks: 0, bikes: 3), status("mid", docks: 6, bikes: 2, ebikes: 2)]))
                ),
                now: { referenceNow }
            ),
            placeSearch: StubPlaces(),
            store: testStore(),
            rides: RideSpy(),
            parsers: [ModelReading(result: model), KeywordRequestParser()],
            backend: nil,
            location: StubLocation(result: .success(LocationFix(location: userLocation, isApproximate: false))),
            sessionID: "bike-test"
        )
    }

    @Test func theModelsBikeReadingIsAnswered() async throws {
        let answer = try await router(model: .nearestBike(.ebike)).answer("I want something electric")
        #expect(answer.text.hasPrefix("The nearest e-bike is at Court and State, "))
        #expect(answer.source == .onDeviceModel)
    }

    @Test(arguments: [ParsedRequest.nearMe, .citywide, .station("e-bike")])
    func aClearBikeRequestWinsOverAnotherModelReading(model: ParsedRequest) async throws {
        let answer = try await router(model: model).answer("where's the nearest e-bike")
        #expect(answer.text.hasPrefix("The nearest e-bike is at Court and State, "))
    }

    @Test func theModelStillDecidesWhenTheRulesDontSeeABike() async throws {
        let answer = try await router(model: .citywide).answer("what's going on across the system")
        #expect(answer.text.hasSuffix("citywide. 1 station is full."))
    }
}
