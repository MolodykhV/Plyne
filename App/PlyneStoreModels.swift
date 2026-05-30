import Foundation
import PlyneCore

/// The two modes offered in the idle picker. A plain `Hashable` enum without
/// associated values so a SwiftUI `Picker` can tag it; mapped to the domain
/// ``SessionMode`` with the configured defaults at start time.
enum PickerMode: CaseIterable, Identifiable {
    case pomodoro
    case flowmodoro

    var id: Self { self }

    var sessionMode: SessionMode {
        switch self {
        case .pomodoro:
            return .pomodoro(workMinutes: Pomodoro.defaultWorkMinutes, breakMinutes: Pomodoro.defaultBreakMinutes)
        case .flowmodoro:
            return .flowmodoro
        }
    }
}

/// The result of attempting to add a retroactive session.
enum RetroactiveOutcome: Equatable {
    /// Saved.
    case added
    /// Not saved: the interval overlaps existing session(s). The view may
    /// re-submit with `force: true` to record it anyway.
    case overlap(count: Int)
    /// Not saved: the inputs were invalid (e.g. non-positive duration).
    case invalid
    /// Not saved: persistence failed (a calm notice has been surfaced).
    case notSaved
}

extension String {
    /// The trimmed string, or `nil` if it is empty once trimmed.
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
