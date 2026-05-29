import Foundation

/// Formatting helpers for the timer's on-screen and spoken durations.
///
/// Display uses a compact clock form (`mm:ss`, or `h:mm:ss` past an hour);
/// accessibility uses a spelled form so VoiceOver reads "five minutes" rather
/// than digit glyphs.
enum DurationFormatting {
    /// A compact clock-style string for a non-negative interval.
    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(max(interval, 0).rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// A spelled, localized duration for accessibility labels.
    static func spoken(_ interval: TimeInterval) -> String {
        Duration.seconds(max(interval, 0)).formatted(
            .units(allowed: [.hours, .minutes, .seconds], width: .wide)
        )
    }

    /// Whole minutes, rounded, for the post-session summary.
    static func wholeMinutes(_ interval: TimeInterval) -> Int {
        Int((max(interval, 0) / 60).rounded())
    }
}
