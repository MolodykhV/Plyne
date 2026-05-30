// swift-tools-version: 6.2
import PackageDescription

// macOS-only: EventKit access. Apple-framework dependent, so it pins the
// platform and never runs on the Linux CI job. The pure classification logic
// (RawCalendarEvent / CalendarBlockMapper / MeetingNow) lives in PlyneCore and
// is tested there; this package is the thin, untested EventKit adapter.
let package = Package(
    name: "PlyneCalendar",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(name: "PlyneCalendar", targets: ["PlyneCalendar"]),
    ],
    dependencies: [
        .package(path: "../PlyneCore"),
    ],
    targets: [
        .target(
            name: "PlyneCalendar",
            dependencies: [.product(name: "PlyneCore", package: "PlyneCore")]
        ),
    ]
)
