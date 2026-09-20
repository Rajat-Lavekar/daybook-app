// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Daybook",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DaybookCore", targets: ["DaybookCore"]),
        .executable(name: "daybook", targets: ["DaybookCLI"]),
        .executable(name: "DaybookPreview", targets: ["DaybookPreview"]),
        .executable(name: "DaybookChecks", targets: ["DaybookChecks"])
    ],
    targets: [
        .target(name: "DaybookCore"),
        .executableTarget(name: "DaybookCLI", dependencies: ["DaybookCore"]),
        .executableTarget(name: "DaybookPreview", dependencies: ["DaybookCore"], path: "App", exclude: ["Info.plist", "Daybook.entitlements"]),
        .target(name: "DaybookTestSupport", dependencies: ["DaybookCore"], path: "Tests/Support"),
        .executableTarget(name: "DaybookChecks", dependencies: ["DaybookTestSupport"], path: "Tests/Runner"),
        .testTarget(name: "DaybookCoreTests", dependencies: ["DaybookTestSupport"])
    ],
    swiftLanguageModes: [.v5]
)
