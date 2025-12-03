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
                guard let repo = GitHubRepo(urlString: repoURLString) else {
                    logger.warning("Invalid GitHub repo URL: \(repoURLString)")
                    continue
                }

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
        logger.trace("Fetching license for \(identity) from \(licenseURL)")

        let (result, response) = try await urlSession.data(from: licenseURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.warning("Invalid HTTP response for \(identity)")
            return nil
        }

        switch httpResponse.statusCode {
        case 200:
            guard let licenseText = String(data: result, encoding: .utf8) else {
                logger.warning("Failed to decode license data for \(identity)")
                return nil
            }
            logger.trace("Successfully fetched LICENSE for \(identity)")
            return License(identity: identity, name: name, license: licenseText)
        case 404:
            logger.trace("LICENSE not found, trying LICENSE.txt for \(identity)")
            let (txtResult, txtResponse) = try await urlSession.data(from: licenseTxtURL)

            if let txtHttpResponse = txtResponse as? HTTPURLResponse,
               txtHttpResponse.statusCode == 200 {
                guard let licenseText = String(data: txtResult, encoding: .utf8) else {
                    logger.warning("Failed to decode license data for \(identity)")
                    return nil
                }
                logger.trace("Successfully fetched LICENSE.txt for \(identity)")
                return License(identity: identity, name: name, license: licenseText)
            } else {
                logger.trace("LICENSE.txt not found, trying License.txt for \(identity)")
                let (txt2Result, txt2Response) = try await urlSession.data(from: licenseTxtURL2)

                if let txt2HttpResponse = txt2Response as? HTTPURLResponse,
                   txt2HttpResponse.statusCode == 200 {
                    guard let licenseText = String(data: txt2Result, encoding: .utf8) else {
                        logger.warning("Failed to decode license data for \(identity)")
                        return nil
                    }
                    logger.trace("Successfully fetched License.txt for \(identity)")
                    return License(identity: identity, name: name, license: licenseText)
                } else {
                    logger.warning("Neither LICENSE, LICENSE.txt, nor License.txt found for \(identity)")
                }
            }
        default:
            logger.warning("Unexpected status code \(httpResponse.statusCode) for \(identity)")
        }

        return nil
    }
}
