// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LicenseCLI",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "LicenseCLI", targets: ["LicenseCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "LicenseCLI",
            dependencies: [
                "LicenseCLICore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "LicenseCLICore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),

        .testTarget(
            name: "LicenseCLITests",
            dependencies: [
                "LicenseCLI",
                "LicenseCLICore"
            ],
            exclude: ["Fixtures/"]
        )
    ]
)
