import CoreGraphics

/// What the on-device Vision pass saw in one frame. Only this (never pixels)
/// is ever handed to a language model.
struct FrameScene: Equatable {
    var horizonDegrees: Double?      // + means the horizon tilts counter-clockwise
    var subject: CGRect?             // normalized, origin top-left, upright image
    var subjectIsFace = false
}

/// One move at a time (rule 2). Ordered by priority.
enum Move: Equatable {
    case level(clockwise: Bool, degrees: Int)
    case shift(Direction)
    case stepBack
    case hold
    case unsure

    enum Direction: String { case left, right, up, down }

    /// Stable key for caching phrasing and counting what the user has learned.
    var key: String {
        switch self {
        case .level(let cw, _): return cw ? "level-cw" : "level-ccw"
        case .shift(let d): return "shift-\(d.rawValue)"
        case .stepBack: return "step-back"
        case .hold: return "hold"
        case .unsure: return "unsure"
        }
    }

    /// Plain facts for the model, and the instant fallback text (rules tier).
    var fact: String {
        switch self {
        case .level(let cw, let d): return "The horizon is tilted \(d) degrees. The user should rotate the phone \(cw ? "clockwise" : "counter-clockwise") slightly."
        case .shift(let d): return "The subject is off the strongest spot in the frame. The user should move the phone \(d.rawValue) a little."
        case .stepBack: return "The subject is cropped at the edge of the frame. The user should take one step back."
        case .hold: return "The framing is good. The user should hold still and take the photo now."
        case .unsure: return "The camera can't find a clear subject or horizon."
        }
    }

    var fallback: String {
        switch self {
        case .level(let cw, _): return cw ? "Tilt right a touch" : "Tilt left a touch"
        case .shift(let d): return "Move \(d.rawValue) a little"
        case .stepBack: return "Take a step back"
        case .hold: return "Hold. Take it."
        case .unsure: return "Not sure yet. Point at what you love."
        }
    }

    var symbol: String {
        switch self {
        case .level(let cw, _): return cw ? "arrow.clockwise" : "arrow.counterclockwise"
        case .shift(.left): return "arrow.left"
        case .shift(.right): return "arrow.right"
        case .shift(.up): return "arrow.up"
        case .shift(.down): return "arrow.down"
        case .stepBack: return "arrow.down.left.and.arrow.up.right"
        case .hold: return "circle.inset.filled"
        case .unsure: return "questionmark.circle"
        }
    }
}

enum RuleEngine {
    static func move(for s: FrameScene) -> Move {
        if let h = s.horizonDegrees, abs(h) >= 2.5, abs(h) < 30 {
            return .level(clockwise: h > 0, degrees: Int(abs(h).rounded()))
        }
        guard let r = s.subject else {
            return s.horizonDegrees == nil ? .unsure : .hold
        }
        // Cropped at an edge: step back (rule of thumb, not a setting).
        if r.minX < 0.02 || r.maxX > 0.98 || (s.subjectIsFace && r.minY < 0.02) || r.width > 0.85 {
            return .stepBack
        }
        // Pull the subject's centre toward the nearest third line horizontally,
        // and keep faces in the upper third.
        let cx = r.midX
        let targetX: CGFloat = abs(cx - 1/3) < abs(cx - 2/3) ? 1/3 : 2/3
        let dx = cx - targetX
        if abs(dx) > 0.08 { return .shift(dx > 0 ? .right : .left) } // move phone toward subject
        if s.subjectIsFace {
            let dy = r.midY - 1/3
            if dy > 0.12 { return .shift(.down) }
        }
        return .hold
    }
}
