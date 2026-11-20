//
//  SpokenVoiceTests.swift
//  DockFinderTests
//
//  The app's own voice: Samantha when present, otherwise quality first,
//  and never the robotic legacy, Eloquence or novelty voices if anything
//  else exists.
//

import Testing
@testable import DockFinder

struct SpokenVoiceTests {
    typealias V = SpokenVoice.Candidate

    private func voice(_ name: String, id: String? = nil, _ quality: V.Quality = .standard,
                       male: Bool = false, novelty: Bool = false, lang: String = "en-US") -> V {
        V(name: name, identifier: id ?? "com.apple.voice.\(name.lowercased())", language: lang,
          quality: quality, isMale: male, isNovelty: novelty)
    }

    private func pick(_ voices: [V], lang: String = "en-US") -> String? {
        SpokenVoice.pickCandidate(from: voices, language: lang)?.name
    }

    @Test func compactSamanthaBeatsAnEnhancedMaleVoice() {
        #expect(pick([voice("Sam", .enhanced, male: true), voice("Samantha")]) == "Samantha")
    }

    @Test func downloadedEnhancedSamanthaBeatsCompactSamantha() {
        let compact = voice("Samantha", id: "com.apple.voice.compact.en-US.Samantha")
        let enhanced = voice("Samantha (Enhanced)", id: "com.apple.voice.enhanced.en-US.Samantha", .enhanced)
        #expect(SpokenVoice.pickCandidate(from: [compact, enhanced], language: "en-US")?.identifier
                == "com.apple.voice.enhanced.en-US.Samantha")
    }

    @Test func samanthaIsPickedEvenWhenThePhoneIsSpanish() {
        #expect(pick([voice("Paulina", .premium, lang: "es-MX"), voice("Samantha")], lang: "es-US") == "Samantha")
    }

    @Test func samanthaOutsideEnUSIsIgnored() {
        #expect(pick([voice("Samantha", lang: "en-GB"), voice("Zoe", .enhanced, lang: "en-US")]) == "Zoe")
    }

    @Test func similarNamesAreNotSamantha() {
        #expect(pick([voice("Samanthas", id: "com.apple.voice.compact.en-US.Samanthas"),
                      voice("Zoe", .premium)]) == "Zoe")
    }

    @Test func withoutSamanthaAPremiumFemaleBeatsADefaultMale() {
        #expect(pick([voice("Sam", male: true), voice("Zoe", .premium)]) == "Zoe")
    }

    @Test func sirIdentifierBeatsNonSiriAtTheSameQuality() {
        #expect(pick([voice("A", .enhanced, male: true), voice("B", id: "com.apple.ttsbundle.siri_B", .enhanced)]) == "B")
    }

    @Test func maleOnlyBreaksTiesAtTheSameQualityAndSiriness() {
        #expect(pick([voice("Zoe", .enhanced), voice("Sam", .enhanced, male: true)]) == "Sam")
    }

    @Test func legacyAndEloquenceVoicesLoseToAnyNormalVoice() {
        let fred = voice("Fred", id: "com.apple.speech.synthesis.voice.Fred", .premium, male: true)
        let eddy = voice("Eddy", id: "com.apple.eloquence.en-US.Eddy", .premium, male: true)
        #expect(pick([fred, eddy, voice("Zoe")]) == "Zoe")
    }

    @Test func noveltyNeverWinsOverANormalVoice() {
        #expect(pick([voice("Bells", .premium, male: true, novelty: true), voice("Zoe")]) == "Zoe")
    }

    @Test func legacyVoiceIsUsedWhenNothingElseExists() {
        let fred = voice("Fred", id: "com.apple.speech.synthesis.voice.Fred", male: true)
        #expect(pick([fred]) == "Fred")
    }

    @Test func noVoicesGivesNil() {
        #expect(pick([]) == nil)
    }
}
