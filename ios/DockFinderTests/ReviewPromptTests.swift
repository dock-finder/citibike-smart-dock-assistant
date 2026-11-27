import Foundation
import Testing
@testable import DockFinder

@MainActor
struct ReviewPromptTests {
    @Test func theFirstSpokenRedirectSurvivesRecreationAndIsRequestedOnce() throws {
        let suite = "ReviewPromptTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let background = ReviewPrompt(defaults: defaults)
        var requests = 0
        #expect(!background.requestIfPending { requests += 1 })
        background.recordSpokenRedirect()
        background.recordSpokenRedirect()

        let foreground = ReviewPrompt(defaults: try #require(UserDefaults(suiteName: suite)))
        #expect(foreground.state == .pendingReview)
        #expect(!foreground.requestIfPending(nil))
        #expect(foreground.state == .pendingReview)
        #expect(foreground.requestIfPending { requests += 1 })
        background.recordSpokenRedirect()
        #expect(!foreground.requestIfPending { requests += 1 })
        #expect(background.state == .reviewRequested)
        #expect(requests == 1)
    }
}
