import Foundation

/// A high-level template for the day's rhythm.
///
/// Per the concept doc (section "Учёт распорядка дня"), presets let the
/// user pick which thresholds and prompts Plyne uses without forcing a
/// "good day / bad day" framing.
public enum DayPreset: String, Hashable, Sendable, Codable, CaseIterable {
    /// Long uninterrupted focus blocks expected.
    case deepWork

    /// Day dominated by meetings; focus blocks are short and bracketed.
    case meetingHeavy

    /// Lower-intensity day. Plyne lowers its prompting cadence.
    case light
}
