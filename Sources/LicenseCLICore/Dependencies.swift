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
            repo?.licenseURL(for: state.revision)
        }

        var licenseTxtURL: URL? {
            repo?.licenseTxtURL(for: state.revision)
        }

        var licenseCapitalTxtURL: URL? {
            repo?.licenseCapitalTxtURL(for: state.revision)
        }

        var name: String {
            repo?.name ?? identity
        }

        private var repo: GitHubRepo? {
            GitHubRepo(urlString: location)
        }
    }
}
