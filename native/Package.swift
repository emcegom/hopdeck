// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HopdeckNative",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "HopdeckNativeCore", targets: ["HopdeckNativeCore"]),
        .executable(name: "HopdeckNative", targets: ["HopdeckNative"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.13.0")
    ],
    targets: [
        .target(
            name: "HopdeckNativeCore",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/Core"
        ),
        .executableTarget(
            name: "HopdeckNative",
            dependencies: [
                "HopdeckNativeCore",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/App"
        ),
        .executableTarget(
            name: "HopdeckNativeCoreChecks",
            dependencies: ["HopdeckNativeCore"],
            path: "Sources/CoreChecks"
        )
    ]
)
