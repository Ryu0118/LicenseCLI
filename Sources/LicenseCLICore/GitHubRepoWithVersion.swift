import Foundation

struct GitHubRepoWithVersion {
    let repo: GitHubRepo
    let version: Version

    enum Version: Equatable {
        case branch(String)
        case tag(String)
        case revision(String)
        case head  // Default if no version specified

        var gitReference: String {
            switch self {
            case .branch(let name), .tag(let name), .revision(let name):
                return name
            case .head:
                return "HEAD"
            }
        }
    }

    /// Parse GitHub URL with optional version specification
    /// Supported formats:
    /// - https://github.com/owner/repo
    /// - https://github.com/owner/repo@branch
    /// - https://github.com/owner/repo@1.2.3
    /// - https://github.com/owner/repo@abc123
    init?(urlString: String) {
        // Split by @ to separate URL and version
        let components = urlString.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        let repoURLString = String(components[0])

        // Parse the base GitHub repo
        guard let repo = GitHubRepo(urlString: repoURLString) else {
            return nil
        }
        self.repo = repo

        // Parse version specification if present
        if components.count > 1 {
            let versionString = String(components[1])
            if versionString.isEmpty {
                return nil // Invalid: URL ends with @
            }

            // Heuristic: if it looks like a semantic version tag, treat as tag
            // Otherwise, could be branch name or revision
            // For simplicity, we'll treat everything as a git reference
            // Git will handle it appropriately (branch, tag, or commit SHA)
            self.version = .tag(versionString)
        } else {
            self.version = .head
        }
    }

    /// Clone URL for git operations
    var cloneURL: String {
        "https://github.com/\(repo.owner)/\(repo.name).git"
    }
}
