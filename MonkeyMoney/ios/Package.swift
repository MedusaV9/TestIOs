// swift-tools-version: 5.9
// Linux-runnable SwiftPM package for the Foundation-only core of Monkey Money:
// content model + loader, economy rules, wheel, jokers, the pure game engine
// with all minigame plugins, the wire protocol and the meta layer (profiles,
// shop, levels). The iPad/iPhone app itself is generated with XcodeGen from
// project.yml; this manifest exists so `swift test` gates the rules on Linux/CI.
// Do NOT add SwiftUI/UIKit/Network files to this target.
import PackageDescription

let package = Package(
    name: "MonkeyMoneyCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MonkeyMoneyCore", targets: ["MonkeyMoneyCore"])
    ],
    targets: [
        .target(
            name: "MonkeyMoneyCore",
            path: "Core"
        ),
        .testTarget(
            name: "MonkeyMoneyCoreTests",
            dependencies: ["MonkeyMoneyCore"],
            path: "CoreTests"
        )
    ]
)
