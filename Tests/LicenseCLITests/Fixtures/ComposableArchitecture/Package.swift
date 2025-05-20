// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HasComposableArchitectureDependency",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "HasComposableArchitectureDependency",
            targets: ["HasComposableArchitectureDependency"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.19.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "HasComposableArchitectureDependency",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .testTarget(
            name: "HasComposableArchitectureDependencyTests",
            dependencies: ["HasComposableArchitectureDependency"]
        ),
    ]
)
