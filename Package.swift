// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GLMUsageMonitor",
    platforms: [.macOS(.v26)],
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
