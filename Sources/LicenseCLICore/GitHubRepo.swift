import Foundation

struct GitHubRepo {
    struct ParsedLocation {
        let owner: String
        let name: String
        let version: String?
    }

    let owner: String
    let name: String

    init(owner: String, name: String) {
        self.owner = owner
        self.name = name
    }

    var identity: String {
        "\(owner)/\(name)".lowercased()
    }

    var licenseURL: URL? {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(name)/HEAD/LICENSE")
    }

    var licenseTxtURL: URL? {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(name)/HEAD/LICENSE.txt")
    }

    var licenseCapitalTxtURL: URL? {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(name)/HEAD/License.txt")
    }

    func licenseURL(for version: String) -> URL? {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(name)/\(version)/LICENSE")
    }

    func licenseTxtURL(for version: String) -> URL? {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(name)/\(version)/LICENSE.txt")
    }

    func licenseCapitalTxtURL(for version: String) -> URL? {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(name)/\(version)/License.txt")
    }

    init?(urlString: String) {
        guard let parsed = Self.parse(urlString: urlString), parsed.version == nil else {
            return nil
        }

        self.init(owner: parsed.owner, name: parsed.name)
    }

    static func parse(urlString: String) -> ParsedLocation? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if let scpStylePath = trimmed.scpStyleGitHubPath {
            return parsePath(scpStylePath)
        }

        guard let url = URL(string: trimmed),
              let host = url.host?.lowercased(),
              host == "github.com" || host == "www.github.com"
        else {
            return nil
        }

        return parsePath(String(url.path.drop(while: { $0 == "/" })))
    }

    private static func parsePath(_ path: String) -> ParsedLocation? {
        guard let (ownerPart, referencePart) = path[...].splitOnce(separator: "/"),
              !ownerPart.isEmpty,
              let parsedReference = parseReference(referencePart)
        else {
            return nil
        }

        return ParsedLocation(
            owner: String(ownerPart),
            name: parsedReference.name,
            version: parsedReference.version
        )
    }

    private static func parseReference(_ reference: Substring) -> (name: String, version: String?)? {
        let repositoryPart: Substring
        let versionPart: Substring?

        if let (repository, version) = reference.splitOnce(separator: "@") {
            repositoryPart = repository
            versionPart = version
        } else {
            repositoryPart = reference
            versionPart = nil
        }

        guard let name = normalizedRepositoryName(from: repositoryPart) else {
            return nil
        }

        guard let versionPart else {
            return (name, nil)
        }

        guard !versionPart.isEmpty else {
            return nil
        }

        return (name, String(versionPart))
    }

    private static func normalizedRepositoryName(from repositoryPart: Substring) -> String? {
        guard !repositoryPart.isEmpty else {
            return nil
        }

        let normalizedPart: Substring
        if repositoryPart.hasSuffix(".git") {
            normalizedPart = repositoryPart.dropLast(4)
        } else {
            normalizedPart = repositoryPart
        }

        guard !normalizedPart.isEmpty else {
            return nil
        }

        return String(normalizedPart)
    }
}

private extension String {
    var scpStyleGitHubPath: String? {
        let prefix = "git@github.com:"
        guard hasPrefix(prefix) else { return nil }
        return String(dropFirst(prefix.count))
    }
}

private extension Substring {
    func splitOnce(separator: Character) -> (Substring, Substring)? {
        guard let separatorIndex = firstIndex(of: separator) else {
            return nil
        }

        let head = self[..<separatorIndex]
        let tailStart = index(after: separatorIndex)
        let tail = self[tailStart...]
        return (head, tail)
    }
}
