// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchMusic",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "NotchMusic", targets: ["NotchMusic"])],
    targets: [
        .executableTarget(name: "NotchMusic"),
        .testTarget(name: "NotchMusicTests", dependencies: ["NotchMusic"])
    ]
)
