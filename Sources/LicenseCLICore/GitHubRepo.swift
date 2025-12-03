import Foundation

struct GitHubRepo {
    let owner: String
    let name: String

    var identity: String {
        "\(owner)/\(name)".lowercased()
    }

    var licenseURL: URL? {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(name)/HEAD/LICENSE")
    }

    var licenseTxtURL: URL? {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(name)/HEAD/LICENSE.txt")
    }

    var licenseTxtURL2: URL? {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(name)/HEAD/License.txt")
    }

    func licenseURL(for version: String) -> URL? {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(name)/\(version)/LICENSE")
    }

    func licenseTxtURL(for version: String) -> URL? {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(name)/\(version)/LICENSE.txt")
    }

    func licenseTxtURL2(for version: String) -> URL? {
        URL(string: "https://raw.githubusercontent.com/\(owner)/\(name)/\(version)/License.txt")
    }

    init?(urlString: String) {
        guard let url = URL(string: urlString) else { return nil }
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count >= 2 else { return nil }

        self.owner = pathComponents[0]
        self.name = pathComponents[1].replacingOccurrences(of: ".git", with: "")
    }
}
