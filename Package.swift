// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Pomodoro",
            path: "Sources/Pomodoro"
        )
    ]
)
