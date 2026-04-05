// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "GLMUsageMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GLMUsageMonitor",
            path: "Sources/GLMUsageMonitor"
        ),
        .testTarget(
            name: "GLMUsageMonitorTests",
            dependencies: ["GLMUsageMonitor"]
        )
    ]
)
