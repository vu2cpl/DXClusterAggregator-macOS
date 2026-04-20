// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DXClusterAggregator",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "DXClusterAggregator",
            path: "DXClusterAggregator",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
