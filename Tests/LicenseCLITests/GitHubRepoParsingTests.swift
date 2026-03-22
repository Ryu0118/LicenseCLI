import Foundation
@testable import LicenseCLICore
import Testing

@Suite
struct GitHubRepoParsingTests {
    @Test
    func parsesSCPStyleGitHubURL() {
        let repo = GitHubRepo(urlString: "git@github.com:apple/swift-collections.git")

        #expect(repo?.owner == "apple")
        #expect(repo?.name == "swift-collections")
    }

    @Test
    func parsesSCPStyleGitHubURLWithVersion() {
        let repo = GitHubRepoWithVersion(urlString: "git@github.com:apple/swift-collections.git@1.1.0")

        #expect(repo?.repo.owner == "apple")
        #expect(repo?.repo.name == "swift-collections")
        #expect(repo?.version == .tag("1.1.0"))
    }

    @Test
    func buildsLicenseURLFromSCPStylePackageResolvedPin() throws {
        let data = Data(
            """
            {
              "pins": [
                {
                  "identity": "mappathkit",
                  "location": "git@github.com:apple/swift-collections.git",
                  "state": {
                    "revision": "abc123"
                  }
                }
              ]
            }
            """.utf8
        )

        let dependencies = try JSONDecoder().decode(Dependencies.self, from: data)

        #expect(
            dependencies.pins.first?.licenseURL?.absoluteString
                == "https://raw.githubusercontent.com/apple/swift-collections/abc123/LICENSE"
        )
        #expect(dependencies.pins.first?.name == "swift-collections")
    }
}
