//
//  DockFinderShortcutsProvider.swift
//  Dock Finder
//
//  App Shortcuts are registered with the system automatically at install
//  time; nothing in the app needs to "enable" them. Phrases that mention a
//  saved place or a station are refreshed whenever those lists change.
//

import AppIntents

struct DockFinderShortcutsProvider: AppShortcutsProvider {
    /// Every phrase is "Ask Dock Finder to/for/if/how …" and says the whole
    /// request in one go, except Ask a Question ("Ask Dock Finder a
    /// question"), which then asks "What do you need?". There's
    /// deliberately no bare "Ask Dock Finder": Siri could match it on the
    /// shared opening and drop the rest.
    ///
    /// A few actions also take the name first, with no "Ask" ("Dock Finder
    /// find a dock", "Dock Finder nearest e-bike"), and the bare name "Dock
    /// Finder" runs Ask a Question. These were added to try on phones; if
    /// one opens the app, goes to another app, or the bare name swallows
    /// longer requests, take it out (removing a phrase doesn't move any
    /// shortcut).
    ///
    /// Phrases with a station multiply by every station Siri knows (up to
    /// 60), so keep those few: the whole list, filled in, stays under about
    /// 900, below the limit Apple sets on an app's phrases.
    ///
    /// **Never reorder or remove these; only append.** iOS remembers which
    /// phrase belongs to which position in this list and doesn't always
    /// re-read it when the app is updated, so reordering once made "start a
    /// ride" run Find Dock. If the list ever has to change shape, also bump
    /// `CURRENT_PROJECT_VERSION` in `Config/DockFinder.xcconfig`, which makes
    /// iOS re-read it. To retire one, replace it in its own position, as
    /// Find Bike replaced Citywide Status, so nothing else moves.
    ///
    /// Siri matches phrases loosely, so keep each action's wording clearly
    /// different from the others' (only Find Dock may say "find a dock"
    /// without a saved place after it). Siri can only fill a blank from a
    /// list the app gives it (saved places, stations); free text such as an
    /// address can't be part of a phrase, so those actions ask for it.
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRideIntent(),
            phrases: [
                "Ask \(.applicationName) to start a ride to \(\.$place)",
                "Ask \(.applicationName) to start riding to \(\.$place)",
                "Ask \(.applicationName) to begin a ride to \(\.$place)",
                "Ask \(.applicationName) to start a ride",
                "Ask \(.applicationName) to begin a ride",
                "Ask \(.applicationName) to start riding",
                // More wordings, with and without "Ask".
                "Ask \(.applicationName) to start a bike ride to \(\.$place)",
                "Ask \(.applicationName) to start a Citi Bike ride to \(\.$place)",
                "Ask \(.applicationName) to ride to \(\.$place)",
                "Ask \(.applicationName) to start a bike ride",
                "\(.applicationName) start a ride to \(\.$place)",
                "\(.applicationName) start riding to \(\.$place)",
                "\(.applicationName) begin a ride to \(\.$place)",
                "\(.applicationName) start a bike ride to \(\.$place)",
                "\(.applicationName) ride to \(\.$place)",
                "\(.applicationName) I'm riding to \(\.$place)",
                "\(.applicationName) I'm heading to \(\.$place)",
                "\(.applicationName) start a ride",
                "\(.applicationName) start a bike ride",
                "\(.applicationName) begin a ride",
                "\(.applicationName) start riding",
            ],
            shortTitle: "Start Ride",
            systemImageName: "figure.outdoor.cycle"
        )
        AppShortcut(
            intent: EndRideIntent(),
            phrases: [
                // "Bike" or "Citi Bike" in each: Maps answers to plain "end
                // my ride" (ending navigation), so Siri sent it there.
                "Ask \(.applicationName) to end my bike ride",
                "Ask \(.applicationName) to stop my bike ride",
                "Ask \(.applicationName) to cancel my bike ride",
                "Ask \(.applicationName) to end my Citi Bike ride",
                // More wordings, with and without "Ask".
                "Ask \(.applicationName) to finish my bike ride",
                "Ask \(.applicationName) to end this bike ride",
                "\(.applicationName) end my bike ride",
                "\(.applicationName) stop my bike ride",
                "\(.applicationName) cancel my bike ride",
                "\(.applicationName) finish my bike ride",
                "\(.applicationName) end my Citi Bike ride",
                "\(.applicationName) I'm done riding",
            ],
            shortTitle: "End Ride",
            systemImageName: "flag.checkered"
        )
        AppShortcut(
            intent: FindDockIntent(),
            phrases: [
                "Ask \(.applicationName) to find a dock",
                "Ask \(.applicationName) to find me a dock",
                "Ask \(.applicationName) to find a dock near me",
                "Ask \(.applicationName) to find an open dock",
                "Ask \(.applicationName) to find the nearest dock",
                "Ask \(.applicationName) for a dock",
                "Ask \(.applicationName) for the nearest dock",
                // Siri often hears "dock" as "doc".
                "Ask \(.applicationName) to find a doc",
                "Ask \(.applicationName) to find me a doc",
                "Ask \(.applicationName) to find a doc near me",
                "Ask \(.applicationName) to find an open doc",
                "Ask \(.applicationName) to find the nearest doc",
                "Ask \(.applicationName) for a doc",
                "Ask \(.applicationName) for the nearest doc",
                // Name first, without "Ask".
                "\(.applicationName) find a dock",
                "\(.applicationName) find me a dock",
                "\(.applicationName) nearest dock",
                "\(.applicationName) find a doc",
                "\(.applicationName) find me a doc",
                "\(.applicationName) nearest doc",
                // More wordings, with and without "Ask".
                "Ask \(.applicationName) where the nearest dock is",
                "Ask \(.applicationName) where the nearest doc is",
                "Ask \(.applicationName) what the nearest dock is",
                "Ask \(.applicationName) what the nearest doc is",
                "Ask \(.applicationName) where's the nearest dock",
                "Ask \(.applicationName) where's the nearest doc",
                "Ask \(.applicationName) what's the nearest dock",
                "Ask \(.applicationName) what's the nearest doc",
                "Ask \(.applicationName) for an open dock",
                "Ask \(.applicationName) for an open doc",
                "Ask \(.applicationName) for a dock near me",
                "Ask \(.applicationName) for a doc near me",
                "Ask \(.applicationName) for the closest dock",
                "Ask \(.applicationName) for the closest doc",
                "Ask \(.applicationName) to find the closest dock",
                "Ask \(.applicationName) to find the closest doc",
                "Ask \(.applicationName) where I can dock",
                "Ask \(.applicationName) where I can doc",
                "Ask \(.applicationName) where I can park",
                "Ask \(.applicationName) where I can return my bike",
                "\(.applicationName) find the nearest dock",
                "\(.applicationName) find the nearest doc",
                "\(.applicationName) find the closest dock",
                "\(.applicationName) find the closest doc",
                "\(.applicationName) find an open dock",
                "\(.applicationName) find an open doc",
                "\(.applicationName) closest dock",
                "\(.applicationName) closest doc",
                "\(.applicationName) dock near me",
                "\(.applicationName) doc near me",
                "\(.applicationName) open docks near me",
                "\(.applicationName) open docs near me",
                "\(.applicationName) where's the nearest dock",
                "\(.applicationName) where's the nearest doc",
                "\(.applicationName) where is the nearest dock",
                "\(.applicationName) where is the nearest doc",
                "\(.applicationName) what's the nearest dock",
                "\(.applicationName) what's the nearest doc",
                "\(.applicationName) what is the nearest dock",
                "\(.applicationName) what is the nearest doc",
                "\(.applicationName) where can I dock",
                "\(.applicationName) where can I doc",
                "\(.applicationName) where can I park",
                "\(.applicationName) where can I return my bike",
            ],
            shortTitle: "Find Dock",
            systemImageName: "bicycle"
        )
        AppShortcut(
            intent: FindDockNearSavedPlaceIntent(),
            phrases: [
                "Ask \(.applicationName) to check my \(\.$place) dock",
                "Ask \(.applicationName) to find a dock near \(\.$place)",
                "Ask \(.applicationName) to find a dock at \(\.$place)",
                "Ask \(.applicationName) for a dock near \(\.$place)",
                "Ask \(.applicationName) to find me a dock near \(\.$place)",
                // Siri often hears "dock" as "doc".
                "Ask \(.applicationName) to check my \(\.$place) doc",
                "Ask \(.applicationName) to find a doc near \(\.$place)",
                "Ask \(.applicationName) to find a doc at \(\.$place)",
                "Ask \(.applicationName) for a doc near \(\.$place)",
                "Ask \(.applicationName) to find me a doc near \(\.$place)",
                // Name first, without "Ask".
                "\(.applicationName) check my \(\.$place) dock",
                "\(.applicationName) check my \(\.$place) doc",
                // More wordings, with and without "Ask".
                "Ask \(.applicationName) for my \(\.$place) dock",
                "Ask \(.applicationName) for my \(\.$place) doc",
                "Ask \(.applicationName) about my \(\.$place) dock",
                "Ask \(.applicationName) about my \(\.$place) doc",
                "Ask \(.applicationName) if my \(\.$place) dock is full",
                "Ask \(.applicationName) if my \(\.$place) doc is full",
                "Ask \(.applicationName) how my \(\.$place) dock is",
                "Ask \(.applicationName) how my \(\.$place) doc is",
                "Ask \(.applicationName) for a dock at \(\.$place)",
                "Ask \(.applicationName) for a doc at \(\.$place)",
                "\(.applicationName) my \(\.$place) dock",
                "\(.applicationName) my \(\.$place) doc",
                "\(.applicationName) is my \(\.$place) dock full",
                "\(.applicationName) is my \(\.$place) doc full",
                "\(.applicationName) how's my \(\.$place) dock",
                "\(.applicationName) how's my \(\.$place) doc",
                "\(.applicationName) find a dock near \(\.$place)",
                "\(.applicationName) find a doc near \(\.$place)",
                "\(.applicationName) find a dock at \(\.$place)",
                "\(.applicationName) find a doc at \(\.$place)",
                "\(.applicationName) find me a dock near \(\.$place)",
                "\(.applicationName) find me a doc near \(\.$place)",
                "\(.applicationName) dock near \(\.$place)",
                "\(.applicationName) doc near \(\.$place)",
            ],
            shortTitle: "Dock Near Saved Place",
            systemImageName: "star"
        )
        AppShortcut(
            intent: FindDockNearPlaceIntent(),
            phrases: [
                "Ask \(.applicationName) to find a dock somewhere else",
                "Ask \(.applicationName) for a dock somewhere else",
                "Ask \(.applicationName) to find me a dock somewhere else",
                "Ask \(.applicationName) to find a dock elsewhere",
                "Ask \(.applicationName) to find me a dock elsewhere",
                "Ask \(.applicationName) to find a dock someplace else",
                "Ask \(.applicationName) to find a dock near another place",
                // Siri often hears "dock" as "doc".
                "Ask \(.applicationName) to find a doc somewhere else",
                "Ask \(.applicationName) for a doc somewhere else",
                "Ask \(.applicationName) to find me a doc somewhere else",
                "Ask \(.applicationName) to find a doc elsewhere",
                "Ask \(.applicationName) to find me a doc elsewhere",
                "Ask \(.applicationName) to find a doc someplace else",
                "Ask \(.applicationName) to find a doc near another place",
                // More wordings, with and without "Ask".
                "\(.applicationName) find a dock somewhere else",
                "\(.applicationName) find a doc somewhere else",
                "\(.applicationName) find me a dock somewhere else",
                "\(.applicationName) find me a doc somewhere else",
                "\(.applicationName) find a dock elsewhere",
                "\(.applicationName) find a doc elsewhere",
                "\(.applicationName) dock somewhere else",
                "\(.applicationName) doc somewhere else",
                "\(.applicationName) find a dock near another place",
                "\(.applicationName) find a doc near another place",
            ],
            shortTitle: "Dock Near a Place",
            systemImageName: "mappin.and.ellipse"
        )
        AppShortcut(
            intent: CheckStationIntent(),
            phrases: [
                "Ask \(.applicationName) to check \(\.$station)",
                "Ask \(.applicationName) if \(\.$station) is full",
                "Ask \(.applicationName) about \(\.$station)",
                "Ask \(.applicationName) to check a station",
                "Ask \(.applicationName) if a station is full",
                // More wordings, with and without "Ask".
                "\(.applicationName) check \(\.$station)",
                "\(.applicationName) is \(\.$station) full",
                "\(.applicationName) check a station",
                "\(.applicationName) is a station full",
            ],
            shortTitle: "Check Station",
            systemImageName: "parkingsign.circle"
        )
        // Took Citywide Status's place: same position, so phones that cached
        // the old list keep every other action where they expect it.
        AppShortcut(
            intent: FindBikeIntent(),
            phrases: [
                "Ask \(.applicationName) for the nearest \(\.$kind)",
                "Ask \(.applicationName) to find the nearest \(\.$kind)",
                "Ask \(.applicationName) where the nearest \(\.$kind) is",
                "Ask \(.applicationName) what the nearest \(\.$kind) is",
                "Ask \(.applicationName) for a \(\.$kind)",
                "Ask \(.applicationName) for an \(\.$kind)",
                "Ask \(.applicationName) to find a \(\.$kind)",
                "Ask \(.applicationName) to find an \(\.$kind)",
                "Ask \(.applicationName) to find me a \(\.$kind)",
                "Ask \(.applicationName) to find me an \(\.$kind)",
                "Ask \(.applicationName) where I can get a \(\.$kind)",
                "Ask \(.applicationName) where I can get an \(\.$kind)",
                "Ask \(.applicationName) for a bike near me",
                "Ask \(.applicationName) for the nearest bike near me",
                // Name first, without "Ask".
                "\(.applicationName) nearest \(\.$kind)",
                "\(.applicationName) find a \(\.$kind)",
                "\(.applicationName) find an \(\.$kind)",
                // More wordings, with and without "Ask".
                "Ask \(.applicationName) where's the nearest \(\.$kind)",
                "Ask \(.applicationName) what's the nearest \(\.$kind)",
                "Ask \(.applicationName) for the closest \(\.$kind)",
                "Ask \(.applicationName) where the closest \(\.$kind) is",
                "Ask \(.applicationName) to find me the nearest \(\.$kind)",
                "Ask \(.applicationName) where I can find a \(\.$kind)",
                "Ask \(.applicationName) where I can find an \(\.$kind)",
                "\(.applicationName) closest \(\.$kind)",
                "\(.applicationName) find me a \(\.$kind)",
                "\(.applicationName) find me an \(\.$kind)",
                "\(.applicationName) find the nearest \(\.$kind)",
                "\(.applicationName) where's the nearest \(\.$kind)",
                "\(.applicationName) where is the nearest \(\.$kind)",
                "\(.applicationName) what's the nearest \(\.$kind)",
                "\(.applicationName) what is the nearest \(\.$kind)",
                "\(.applicationName) where can I get a \(\.$kind)",
                "\(.applicationName) where can I get an \(\.$kind)",
                "\(.applicationName) I need a \(\.$kind)",
                "\(.applicationName) I need an \(\.$kind)",
                "\(.applicationName) get me a \(\.$kind)",
                "\(.applicationName) get me an \(\.$kind)",
                "\(.applicationName) bike near me",
            ],
            shortTitle: "Find Bike",
            systemImageName: "bicycle.circle"
        )
        AppShortcut(
            intent: DirectMeIntent(),
            phrases: [
                "Ask \(.applicationName) to direct me to \(\.$place)",
                "Ask \(.applicationName) to guide me to \(\.$place)",
                "Ask \(.applicationName) to take me to \(\.$place)",
                "Ask \(.applicationName) for directions to \(\.$place)",
                "Ask \(.applicationName) to direct me",
                "Ask \(.applicationName) to direct me there",
                "Ask \(.applicationName) to take me there",
                "Ask \(.applicationName) to guide me to a dock",
                "Ask \(.applicationName) for directions",
                // Siri often hears "dock" as "doc".
                "Ask \(.applicationName) to guide me to a doc",
                // More wordings, with and without "Ask".
                "Ask \(.applicationName) to navigate me to \(\.$place)",
                "Ask \(.applicationName) to get me to \(\.$place)",
                "Ask \(.applicationName) to guide me there",
                "Ask \(.applicationName) to give me directions",
                "\(.applicationName) direct me to \(\.$place)",
                "\(.applicationName) guide me to \(\.$place)",
                "\(.applicationName) take me to \(\.$place)",
                "\(.applicationName) directions to \(\.$place)",
                "\(.applicationName) navigate me to \(\.$place)",
                "\(.applicationName) direct me",
                "\(.applicationName) direct me there",
                "\(.applicationName) take me there",
                "\(.applicationName) guide me to a dock",
                "\(.applicationName) guide me to a doc",
                "\(.applicationName) directions",
            ],
            shortTitle: "Direct Me",
            systemImageName: "location.north.line"
        )
        AppShortcut(
            intent: StopDirectionsIntent(),
            phrases: [
                // Not "stop/cancel directions": Maps answers to that too, so
                // Siri asked "Dock Finder or Maps?" every time.
                "Ask \(.applicationName) to stop guiding me",
                "Ask \(.applicationName) to stop guiding me to the dock",
                "Ask \(.applicationName) to stop guiding",
                "Ask \(.applicationName) to stop guidance",
                "Ask \(.applicationName) to cancel guidance",
                // Siri often hears "dock" as "doc".
                "Ask \(.applicationName) to stop guiding me to the doc",
                // More wordings, with and without "Ask".
                "\(.applicationName) stop guiding me",
                "\(.applicationName) stop guiding",
                "\(.applicationName) stop guidance",
                "\(.applicationName) cancel guidance",
                "\(.applicationName) stop guiding me to the dock",
                "\(.applicationName) stop guiding me to the doc",
            ],
            shortTitle: "Stop Directions",
            systemImageName: "location.slash"
        )
        // iOS allows at most 10 App Shortcuts per app; this is the 10th.
        AppShortcut(
            intent: AskDockFinderIntent(),
            phrases: [
                "Ask \(.applicationName) a question",
                "Ask \(.applicationName) for help with a dock",
                // Siri often hears "dock" as "doc".
                "Ask \(.applicationName) for help with a doc",
                // Name first: then "What do you need?". The bare name too, so
                // "Hey Siri, Dock Finder" asks instead of only opening the app.
                "\(.applicationName) question",
                "\(.applicationName) I have a question",
                "\(.applicationName)",
                // More wordings, with and without "Ask".
                "\(.applicationName) for help with a dock",
                "\(.applicationName) for help with a doc",
            ],
            shortTitle: "Ask a Question",
            systemImageName: "bubble.left"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .teal
}
