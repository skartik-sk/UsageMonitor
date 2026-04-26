// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "UsageMonitor",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "UsageMonitor",
            path: "Sources/UsageMonitor"
        ),
        .testTarget(
            name: "UsageMonitorTests",
            dependencies: ["UsageMonitor"]
        )
    ]
)
