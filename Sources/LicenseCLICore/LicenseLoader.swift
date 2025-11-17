import Foundation

struct LicenseLoader {
    let urlSession: URLSession

    func load(for dependencies: Dependencies) async throws -> [License] {
        logger.info("⬇️ Loading licenses for \(dependencies.pins.count) dependencies")

        let licenses = try await withThrowingTaskGroup(of: (Dependencies.Pin, Data)?.self) { group in
            for pin in dependencies.pins {
                guard let licenseURL = pin.licenseURL,
                      let licenseTxtURL = pin.licenseTxtURL
                else {
                    logger.error("Cannot find license URL for: \(pin.identity) at \(pin.location)")
                    throw RunnerError.cannotFindLicenseURL(location: pin.location)
                }

                group.addTask {
                    logger.trace("Fetching license for \(pin.identity) from \(licenseURL)")

                    let (result, response) = try await urlSession.data(from: licenseURL)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        logger.warning("Invalid HTTP response for \(pin.identity)")
                        return nil
                    }

                    switch httpResponse.statusCode {
                    case 200:
                        logger.trace("Successfully fetched LICENSE for \(pin.identity)")
                        return (pin, result)
                    case 404:
                        logger.trace("LICENSE not found, trying LICENSE.txt for \(pin.identity)")
                        let (result, response) = try await urlSession.data(from: licenseTxtURL)

                        if (response as? HTTPURLResponse)?.statusCode != 404 {
                            logger.trace("Successfully fetched LICENSE.txt for \(pin.identity)")
                            return (pin, result)
                        } else {
                            logger.warning("Neither LICENSE nor LICENSE.txt found for \(pin.identity)")
                        }
                    default:
                        logger.warning("Unexpected status code \(httpResponse.statusCode) for \(pin.identity)")
                        break
                    }

                    return nil
                }
            }

            return try await group.compactMap { $0 }
                .reduce(into: [(Dependencies.Pin, Data)]()) { partialResult, element in
                    partialResult.append(element)
                }
                .compactMap { element -> (Dependencies.Pin, String)? in
                    guard let license = String(data: element.1, encoding: .utf8) else {
                        logger.warning("Failed to decode license data for \(element.0.identity)")
                        return nil
                    }
                    return (element.0, license)
                }
                .sorted {
                    (dependencies.pins.firstIndex(of: $0.0) ?? 0) < (dependencies.pins.firstIndex(of: $1.0) ?? 0)
                }
                .map { License(identity: $0.0.identity, name: $0.0.name, license: $0.1) }
        }

        logger.info("✨ Successfully loaded \(licenses.count) licenses")
        return licenses
    }
}
