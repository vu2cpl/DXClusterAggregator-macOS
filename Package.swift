// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FT8ClusterAggregator",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "FT8ClusterAggregator",
            path: "FT8ClusterAggregator"
        )
    ]
)
