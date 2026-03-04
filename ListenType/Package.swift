// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ListenType",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ListenType",
            path: "Sources/ListenType",
            exclude: ["Info.plist", "ListenType.entitlements"]
        )
    ]
)
