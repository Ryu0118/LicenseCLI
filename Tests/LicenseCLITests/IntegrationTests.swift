@testable import LicenseCLI
@testable import LicenseCLICore
import Testing
import Foundation

@Suite
final class IntegrationTests{
    let outputDirURL: URL
    let outputFileURL: URL
    let tca1FixtureURL: URL
    let tca2FixtureURL: URL
    let nioFixtureURL: URL
    let cowBoxFixtureURL: URL
    let printLicensesURL: URL
    let binaryOutputURL: URL
    let fileManager: FileManager

    let outputFileName = "Licenses"

    let allFixtureDependencies: Set<String> = [
        "combine-schedulers",
        "swift-custom-dump",
        "swift-navigation",
        "swift-concurrency-extras",
        "swift-dependencies",
        "swift-nio",
        "swift-composable-architecture",
        "swift-perception",
        "swift-collections",
        "swift-syntax",
        "swift-clocks",
        "swift-identified-collections",
        "CoWBox",
        "swift-system",
        "swift-case-paths",
        "xctest-dynamic-overlay",
        "swift-atomics",
        "swift-sharing"
    ]

    init() throws {
        let fixtureURL = URL(filePath: #filePath).deletingLastPathComponent().appending(component: "Fixtures")
        outputDirURL = fixtureURL.appending(component: "output")
        outputFileURL = outputDirURL.appending(component: outputFileName).appendingPathExtension("swift")
        fileManager = FileManager.default
        tca1FixtureURL = fixtureURL.appending(component: "ComposableArchitecture1")
        tca2FixtureURL = fixtureURL.appending(component: "ComposableArchitecture2")
        nioFixtureURL = fixtureURL.appending(component: "NIO")
        cowBoxFixtureURL = fixtureURL.appending(component: "HasCoWBox")
        printLicensesURL = fixtureURL.appending(component: "PrintLicenses").appendingPathExtension("swift")
        binaryOutputURL = outputDirURL.appending(component: "main")

        try fileManager.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
    }

    deinit {
        try? fileManager.removeItem(at: outputDirURL)
        try? fileManager.removeItem(at: tca1FixtureURL.appending(component: "Package.resolved"))
        try? fileManager.removeItem(at: tca2FixtureURL.appending(component: "Package.resolved"))
        try? fileManager.removeItem(at: nioFixtureURL.appending(component: "Package.resolved"))
        try? fileManager.removeItem(at: cowBoxFixtureURL.appending(component: "Package.resolved"))
    }

    @Test
    func testMultiplePackageLicenses() async throws {
        try SwiftPackageValidator().validate(
            packageDirectoryPaths: [
                tca1FixtureURL.path(percentEncoded: false),
                tca2FixtureURL.path(percentEncoded: false),
                nioFixtureURL.path(percentEncoded: false),
                cowBoxFixtureURL.path(percentEncoded: false),
            ],
            outputDirectoryPath: outputDirURL.path(percentEncoded: false),
            fileName: outputFileName
        )
        try await Runner().run(
            packageDirectoryPaths: [
                tca1FixtureURL.path(percentEncoded: false),
                tca2FixtureURL.path(percentEncoded: false),
                nioFixtureURL.path(percentEncoded: false),
                cowBoxFixtureURL.path(percentEncoded: false),
            ],
            outputDirectoryPath: outputDirURL.path(percentEncoded: false),
            fileName: outputFileName
        )

        #expect(
            fileManager.fileExists(atPath: outputFileURL.path(percentEncoded: false))
        )

        #expect(throws: Never.self) {
            try Command.run(
                launchPath: "/usr/bin/xcrun",
                arguments: [
                    "swiftc",
                    outputFileURL.path(percentEncoded: false),
                    printLicensesURL.path(percentEncoded: false),
                    "-o",
                    binaryOutputURL.path(percentEncoded: false),
                ]
            )
        }

        let namesData: Data = try #require(
            try Command.run(
                launchPath: binaryOutputURL.path(percentEncoded: false),
                arguments: []
            )
        )

        let names = try JSONDecoder().decode(Set<String>.self, from: namesData)

        #expect(names == allFixtureDependencies)
    }
}

