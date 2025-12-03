import Foundation

struct LicenseLoader {
    let urlSession: URLSession

    func load(for dependencies: Dependencies) async throws -> [License] {
        logger.info("⬇️ Loading licenses for \(dependencies.pins.count) dependencies")

        let licenses = try await withThrowingTaskGroup(of: License?.self) { group in
            for pin in dependencies.pins {
                guard let licenseURL = pin.licenseURL,
                      let licenseTxtURL = pin.licenseTxtURL,
                      let licenseTxtURL2 = pin.licenseTxtURL2
                else {
                    logger.error("Cannot find license URL for: \(pin.identity) at \(pin.location)")
                    throw RunnerError.cannotFindLicenseURL(location: pin.location)
                }

                group.addTask {
                    try await fetchLicense(
                        identity: pin.identity,
                        name: pin.name,
                        licenseURL: licenseURL,
                        licenseTxtURL: licenseTxtURL,
                        licenseTxtURL2: licenseTxtURL2
                    )
                }
            }

            return try await group.reduce(into: [License]()) { result, license in
                if let license {
                    result.append(license)
                }
            }
        }

        logger.info("✨ Successfully loaded \(licenses.count) licenses")
        return licenses
    }

    func load(for repoURLs: [String]) async throws -> [License] {
        guard !repoURLs.isEmpty else { return [] }

        logger.info("⬇️ Loading licenses for \(repoURLs.count) GitHub repositories")

        let licenses = try await withThrowingTaskGroup(of: License?.self) { group in
            for repoURLString in repoURLs {
                // Try to parse as GitHubRepoWithVersion first (supports @version)
                if let repoWithVersion = GitHubRepoWithVersion(urlString: repoURLString) {
                    let repo = repoWithVersion.repo
                    let version = repoWithVersion.version.gitReference
                    
                    guard let licenseURL = repo.licenseURL(for: version),
                          let licenseTxtURL = repo.licenseTxtURL(for: version),
                          let licenseTxtURL2 = repo.licenseTxtURL2(for: version) else {
                        logger.warning("Cannot find license URL for: \(repo.identity) @ \(version)")
                        continue
                    }

                    group.addTask {
                        try await fetchLicense(
                            identity: repo.identity,
                            name: repo.name,
                            licenseURL: licenseURL,
                            licenseTxtURL: licenseTxtURL,
                            licenseTxtURL2: licenseTxtURL2
                        )
                    }
                } else if let repo = GitHubRepo(urlString: repoURLString) {
                    // Fallback to GitHubRepo (no version specified, use HEAD)
                    guard let licenseURL = repo.licenseURL,
                          let licenseTxtURL = repo.licenseTxtURL,
                          let licenseTxtURL2 = repo.licenseTxtURL2
                    else {
                        continue
                    }

                    group.addTask {
                        try await fetchLicense(
                            identity: repo.identity,
                            name: repo.name,
                            licenseURL: licenseURL,
                            licenseTxtURL: licenseTxtURL,
                            licenseTxtURL2: licenseTxtURL2
                        )
                    }
                } else {
                    logger.warning("Invalid GitHub repo URL: \(repoURLString)")
                    continue
                }
            }

            return try await group.reduce(into: [License]()) { result, license in
                if let license {
                    result.append(license)
                }
            }
        }

        logger.info("✨ Successfully loaded \(licenses.count) licenses from GitHub repositories")
        return licenses
    }

    func fetchLicense(
        identity: String,
        name: String,
        licenseURL: URL,
        licenseTxtURL: URL,
        licenseTxtURL2: URL
    ) async throws -> License? {
        // Try LICENSE first
        if let license = try await tryFetchLicense(from: licenseURL, identity: identity, name: name, fileName: "LICENSE") {
            return license
        }

        // Try LICENSE.txt as fallback
        if let license = try await tryFetchLicense(from: licenseTxtURL, identity: identity, name: name, fileName: "LICENSE.txt") {
            return license
        }

        // Try License.txt as final fallback
        if let license = try await tryFetchLicense(from: licenseTxtURL2, identity: identity, name: name, fileName: "License.txt") {
            return license
        }

        logger.warning("Neither LICENSE, LICENSE.txt, nor License.txt found for \(identity)")
        return nil
    }

    private func tryFetchLicense(from url: URL, identity: String, name: String, fileName: String) async throws -> License? {
        logger.trace("Fetching license for \(identity) from \(url)")

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.warning("Invalid HTTP response for \(identity)")
            return nil
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                logger.trace("\(fileName) not found for \(identity)")
            } else {
                logger.warning("Unexpected status code \(httpResponse.statusCode) for \(identity) when fetching \(fileName)")
            }
            return nil
        }

        guard let licenseText = String(data: data, encoding: .utf8) else {
            logger.warning("Failed to decode license data for \(identity)")
            return nil
        }

        logger.trace("Successfully fetched \(fileName) for \(identity)")
        return License(identity: identity, name: name, license: licenseText)
    }
}
