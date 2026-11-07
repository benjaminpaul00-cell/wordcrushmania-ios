// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WordCrushManiaCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "GameCore", targets: ["GameCore"])],
    targets: [
        .target(name: "GameCore", path: "Sources/GameCore", resources: [.process("Resources")]),
        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"], path: "Tests/GameCoreTests")
    ]
)
