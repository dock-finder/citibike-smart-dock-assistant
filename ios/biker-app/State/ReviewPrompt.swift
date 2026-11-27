import Foundation

@MainActor
final class ReviewPrompt {
    static let shared = ReviewPrompt()

    enum State: String {
        case notEligible = "not_eligible"
        case pendingReview = "pending_review"
        case reviewRequested = "review_requested"
    }

    private static let key = "valueTriggeredReviewState"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var state: State {
        defaults.string(forKey: Self.key).flatMap(State.init(rawValue:)) ?? .notEligible
    }

    func recordSpokenRedirect() {
        guard state == .notEligible else { return }
        defaults.set(State.pendingReview.rawValue, forKey: Self.key)
    }

    /// Called at foreground activation. An unavailable request leaves the
    /// redirect pending until a later activation.
    @discardableResult
    func requestIfPending(_ request: (() -> Void)?) -> Bool {
        guard state == .pendingReview, let request else { return false }
        // Claim it immediately before the synchronous StoreKit call. Both
        // state transitions run on the main actor, including in background.
        defaults.set(State.reviewRequested.rawValue, forKey: Self.key)
        request()
        return true
    }
}
