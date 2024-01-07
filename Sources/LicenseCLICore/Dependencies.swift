import Foundation

struct Dependencies: Decodable, Equatable {
    let pins: [Pin]

    struct Pin: Decodable, Equatable {
        let identity: String
        let location: String
        let state: State

        struct State: Decodable, Equatable {
            let revision: String
        }

        var licenseURL: URL? {
            URL(string: location.rawGithubContentURL())?
                .appendingPathComponent(state.revision)
                .appendingPathComponent("LICENSE")
        }

        var licenseTxtURL: URL? {
            URL(string: location.rawGithubContentURL())?
                .appendingPathComponent(state.revision)
                .appendingPathComponent("LICENSE.txt")
        }
    }
}

fileprivate extension String {
    func rawGithubContentURL() -> String {
        replacingOccurrences(of: ".git", with: "").replacingOccurrences(
            of: "github.com",
            with: "raw.githubusercontent.com"
        )
    }
}
