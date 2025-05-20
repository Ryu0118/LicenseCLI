@testable import LicenseCLI
@testable import LicenseCLICore
import Testing
import Foundation

@Suite
final class IntegrationTests{
    let outputDirURL: URL
    let outputFileURL: URL
    let tcaFixtureURL: URL
    let nioFixtureURL: URL
    let fileManager: FileManager

    let outputFileName = "Licenses"

    init() throws {
        let fixtureURL = URL(filePath: #filePath).deletingLastPathComponent().appending(component: "Fixtures")
        outputDirURL = fixtureURL.appending(component: "output")
        outputFileURL = outputDirURL.appending(component: outputFileName).appendingPathExtension("swift")
        fileManager = FileManager.default
        tcaFixtureURL = fixtureURL.appending(component: "ComposableArchitecture")
        nioFixtureURL = fixtureURL.appending(component: "NIO")

        try fileManager.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
    }

    deinit {
        try? fileManager.removeItem(at: outputDirURL)
        try? fileManager.removeItem(at: tcaFixtureURL.appending(component: "Package.resolved"))
        try? fileManager.removeItem(at: nioFixtureURL.appending(component: "Package.resolved"))
    }

    @Test
    func testMultiplePackageLicenses() async throws {
        try SwiftPackageValidator().validate(
            packageDirectoryPaths: [
                tcaFixtureURL.path(percentEncoded: false),
                nioFixtureURL.path(percentEncoded: false),
            ],
            outputDirectoryPath: outputDirURL.path(percentEncoded: false),
            fileName: outputFileName
        )
        try await Runner().run(
            packageDirectoryPaths: [
                tcaFixtureURL.path(percentEncoded: false),
                nioFixtureURL.path(percentEncoded: false),
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
                    outputFileURL.path(percentEncoded: false)
                ]
            )
        }
    }
}

