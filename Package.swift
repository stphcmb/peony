// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PositiveVibeOnly",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic: the content model and the day -> greeting rule.
        // No AppKit/SwiftUI, no bundle resources — kept easy to test.
        .target(
            name: "PositiveVibeOnlyCore",
            path: "Sources/PositiveVibeOnlyCore"
        ),

        // The menu bar app: status item, popover, bundled content.json.
        .executableTarget(
            name: "PositiveVibeOnlyApp",
            dependencies: ["PositiveVibeOnlyCore"],
            path: "Sources/PositiveVibeOnlyApp",
            resources: [
                .copy("Resources/content.json"),
                .copy("Resources/Fonts/Fraunces.ttf"),
                .copy("Resources/Fonts/Karla.ttf")
            ]
        ),

        // Plain assertion-based checks for Core (see its main.swift for why
        // this isn't XCTest). Run with: swift run CoreTests
        .executableTarget(
            name: "CoreTests",
            dependencies: ["PositiveVibeOnlyCore"],
            path: "Sources/CoreTests"
        )
    ]
)
