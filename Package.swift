// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InfisicalMenu",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "InfisicalMenu",
            path: "InfisicalMenu",
            exclude: ["Info.plist", "InfisicalMenu.entitlements"],
            resources: [.copy("Assets.xcassets")]
        ),
    ]
)
