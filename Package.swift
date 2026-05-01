// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Kubera",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "KuberaCore", targets: ["KuberaCore"]),
        .executable(name: "KuberaApp", targets: ["KuberaApp"]),
        .executable(name: "kubera", targets: ["KuberaCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "KuberaCore",
            path: "KuberaCore"
        ),
        .executableTarget(
            name: "KuberaApp",
            dependencies: ["KuberaCore"],
            path: "Kubera",
            exclude: ["Info.plist", "Kubera.entitlements"],
            resources: [.copy("Assets.xcassets")]
        ),
        .executableTarget(
            name: "KuberaCLI",
            dependencies: [
                "KuberaCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "KuberaCLI"
        ),
    ]
)
