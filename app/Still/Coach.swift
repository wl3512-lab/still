import Foundation
import FoundationModels
import FirebaseCore
import FirebaseAILogic

/// Hybrid phrasing. The rule engine decides *what* to say; a language model only
/// turns that decision into a few friendly words.
///   1. On-device: Apple Foundation Models (offline, private).
///   2. Cloud fallback via Firebase AI Logic (Gemini) when the device has no
///      Apple Intelligence. It receives the one-sentence fact, never the image.
///   3. Rules: built-in text if neither is available. Coaching never waits on a model.
@MainActor
@Observable
final class Coach {
    enum Tier: String { case onDevice = "On-device", cloud = "Cloud", rules = "Rules" }

    private(set) var tier: Tier = .rules
    private var phrases: [String: String] = [:]
    private var inFlight: Set<String> = []
    private var failures = 0
    private var makeSession: (() -> LanguageModelSession)?

    static let instructions = """
    You are a calm photo coach for people who are not photographers. \
    You get one fact about the photo being framed. Reply with ONE instruction of at most 7 words. \
    Plain words only: no camera jargon, no settings, no praise or judgment, no emoji, no quotes.
    """

    init() { configure(preferCloud: false) }

    var canUseCloud: Bool {
        guard #available(iOS 27.0, *) else { return false } // Gemini-as-LanguageModel needs iOS 27
        return FirebaseApp.app() != nil
    }
    var onDeviceAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// `preferCloud` exists only so the demo can show both paths on one phone.
    func configure(preferCloud: Bool) {
        phrases = [:]; failures = 0
        if onDeviceAvailable && !preferCloud {
            tier = .onDevice
            // Every prompt is a fixed, app-written fact (no user text), so the
            // permissive guardrail is safe and avoids an extra filter model.
            let local = SystemLanguageModel(guardrails: .permissiveContentTransformations)
            makeSession = { LanguageModelSession(model: local, instructions: Self.instructions) }
        } else if canUseCloud, #available(iOS 27.0, *) {
            tier = .cloud
            let gemini = FirebaseAI.firebaseAI(backend: .googleAI())
                .geminiLanguageModel(name: "gemini-3.5-flash-lite")
            makeSession = { LanguageModelSession(model: gemini, instructions: Self.instructions) }
        } else {
            tier = .rules
            makeSession = nil
        }
    }

    /// Returns the best text available right now and fetches a better one in the
    /// background (cached per move, so each move costs at most one model call).
    func phrase(for move: Move) -> String {
        let key = move.key
        if let p = phrases[key] { return p }
        if let make = makeSession, !inFlight.contains(key) {
            inFlight.insert(key)
            let fact = move.fact
            Task {
                defer { inFlight.remove(key) }
                do {
                    let reply = try await make().respond(to: fact).content
                    let clean = reply.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"")))
                    print("still.coach [\(tier.rawValue)] \(key) -> \(clean)")
                    if !clean.isEmpty, clean.split(separator: " ").count <= 10 { phrases[key] = clean }
                    failures = 0
                } catch {
                    print("still.coach [\(tier.rawValue)] \(key) failed: \(error)")
                    // Honest when unsure: after repeated failures, stop asking and
                    // show the badge as Rules instead of pretending a model is on.
                    failures += 1
                    if failures >= 3 { tier = .rules; makeSession = nil }
                    else { phrases[key] = move.fallback } // no retry storm for this move
                    // Offline or model busy: keep the rules text. Honest, never blocking.
                }
            }
        }
        return move.fallback
    }
}

/// Rule 6, fade as you learn: after a move has been followed a few times,
/// show only the arrow for it.
enum Learning {
    static let threshold = 5
    static func followed(_ move: Move) {
        let k = "followed." + move.key
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: k) + 1, forKey: k)
    }
    static func isLearned(_ move: Move) -> Bool {
        UserDefaults.standard.integer(forKey: "followed." + move.key) >= threshold
    }
    static func reset() {
        for (k, _) in UserDefaults.standard.dictionaryRepresentation() where k.hasPrefix("followed.") {
            UserDefaults.standard.removeObject(forKey: k)
        }
    }
}
