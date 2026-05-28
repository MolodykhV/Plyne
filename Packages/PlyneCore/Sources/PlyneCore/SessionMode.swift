import Foundation

/// The two timing modes Plyne supports plus the overflow phase that may
/// trail a Pomodoro or Flowmodoro session.
///
/// Per the concept doc (section "Ядро: гибридный таймер") the user moves
/// between Pomodoro and Flowmodoro at will, and either may extend into a
/// short overflow phase if they choose to stay in flow when the bell rings.
public enum SessionMode: Hashable, Sendable, Codable {
    /// Fixed-length Pomodoro cycle.
    case pomodoro(workMinutes: Int, breakMinutes: Int)

    /// Open-ended session. Length is decided by the user; the matching break
    /// length is recommended by ``Flowmodoro/recommendedBreak(after:)``.
    case flowmodoro

    /// 5–15 minute extension on top of an already-completed session,
    /// pointing back at its parent session id.
    case overflow(parent: UUID)

    /// Throws if the mode has invalid parameters.
    public func validate() throws {
        if case let .pomodoro(work, breakMinutes) = self {
            guard work > 0, breakMinutes >= 0 else {
                throw DomainError.invalidPomodoroDurations(
                    workMinutes: work,
                    breakMinutes: breakMinutes
                )
            }
        }
    }
}

// MARK: - Codable

// Hand-written rather than synthesized: this type is persisted (SwiftData,
// step 1.4) and exported (JSON/CSV, Phase 3), so the wire shape is a stable
// contract. A flat `{"type": ...}` discriminator is migration-friendly and
// readable; the synthesized nested form (`{"pomodoro": {...}}`) is neither.
// `SessionModeTests` locks this shape against fixture JSON.
extension SessionMode {
    private enum CodingKeys: String, CodingKey {
        case type
        case workMinutes
        case breakMinutes
        case parent
    }

    private enum Tag: String, Codable {
        case pomodoro
        case flowmodoro
        case overflow
    }

    /// Decodes the flat tagged representation documented above.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Tag.self, forKey: .type) {
        case .pomodoro:
            self = .pomodoro(
                workMinutes: try container.decode(Int.self, forKey: .workMinutes),
                breakMinutes: try container.decode(Int.self, forKey: .breakMinutes)
            )
        case .flowmodoro:
            self = .flowmodoro
        case .overflow:
            self = .overflow(parent: try container.decode(UUID.self, forKey: .parent))
        }
    }

    /// Encodes the flat tagged representation documented above.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .pomodoro(workMinutes, breakMinutes):
            try container.encode(Tag.pomodoro, forKey: .type)
            try container.encode(workMinutes, forKey: .workMinutes)
            try container.encode(breakMinutes, forKey: .breakMinutes)
        case .flowmodoro:
            try container.encode(Tag.flowmodoro, forKey: .type)
        case let .overflow(parent):
            try container.encode(Tag.overflow, forKey: .type)
            try container.encode(parent, forKey: .parent)
        }
    }
}
