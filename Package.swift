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
        .target(name: "DaybookCore", path: "src/core"),
        .executableTarget(name: "DaybookCLI", dependencies: ["DaybookCore"], path: "src/cli"),
        .executableTarget(name: "DaybookPreview", dependencies: ["DaybookCore"], path: "app", exclude: ["Info.plist", "Daybook.entitlements"]),
        .target(name: "DaybookTestSupport", dependencies: ["DaybookCore"], path: "tests/support"),
        .executableTarget(name: "DaybookChecks", dependencies: ["DaybookTestSupport"], path: "tests/runner"),
        .testTarget(name: "DaybookCoreTests", dependencies: ["DaybookTestSupport"], path: "tests/core")
    ],
    swiftLanguageModes: [.v5]
)
