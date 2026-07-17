// swift-tools-version: 6.3

import Foundation
import PackageDescription

var targets: [Target] = [
    .executableTarget(
        name: "MacTerminalTracker",
        dependencies: [
            .product(name: "SwiftTerm", package: "SwiftTerm"),
        ],
        resources: [
            .process("Resources"),
            .copy("../../Plugins"),
        ],
        linkerSettings: [
            .linkedFramework("AppKit"),
            .linkedFramework("SwiftUI"),
            .linkedLibrary("sqlite3"),
        ]
    ),
]

// Tests/ is gitignored — include the target only when present locally.
let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let localTestsDirectory = packageDirectory.appendingPathComponent("Tests/MacTerminalTrackerTests")
if FileManager.default.fileExists(atPath: localTestsDirectory.path) {
    targets.append(
        .testTarget(
            name: "MacTerminalTrackerTests",
            dependencies: ["MacTerminalTracker"]
        )
    )
}

let package = Package(
    name: "MacTerminalTracker",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "KoobShell",
            targets: ["MacTerminalTracker"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.0.0"),
    ],
    targets: targets,
    swiftLanguageModes: [.v6]
)
