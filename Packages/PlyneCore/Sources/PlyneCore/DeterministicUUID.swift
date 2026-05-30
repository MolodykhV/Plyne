import Foundation

/// Derives a stable `UUID` from a string, so a calendar event keeps the same
/// ``CalendarBlock`` id across repeated fetches (EventKit identifiers are not
/// UUIDs). Foundation-only — two FNV-1a 64-bit lanes fill the 128 bits — so it
/// builds and tests on Linux without CryptoKit. Not for security; collision
/// resistance only needs to hold across one day's events.
public enum DeterministicUUID {
    /// A stable UUID derived from `string` (same input → same UUID).
    public static func from(_ string: String) -> UUID {
        let high = fnv1a(string, seed: 0xcbf2_9ce4_8422_2325)
        let low = fnv1a(string, seed: 0x8422_2325_cbf2_9ce4)
        var bytes = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: high.bigEndian) { for index in 0..<8 { bytes[index] = $0[index] } }
        withUnsafeBytes(of: low.bigEndian) { for index in 0..<8 { bytes[8 + index] = $0[index] } }
        // Stamp the RFC 4122 version (4) and variant bits so it's well-formed.
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func fnv1a(_ string: String, seed: UInt64) -> UInt64 {
        var hash = seed
        for byte in string.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
