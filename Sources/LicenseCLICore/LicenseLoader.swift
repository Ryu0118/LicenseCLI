import Foundation

struct LicenseLoader {
    let urlSession: URLSession

    func load(for dependencies: Dependencies) async throws -> [License] {
        try await withThrowingTaskGroup(of: (Dependencies.Pin, Data)?.self) { group in
            for pin in dependencies.pins {
                guard let licenseURL = pin.licenseURL,
                      let licenseTxtURL = pin.licenseTxtURL
                else {
                    throw RunnerError.cannotFindLicenseURL(location: pin.location)
                }

                group.addTask {
                    let (result, response) = try await urlSession.data(from: licenseURL)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        return nil
                    }

                    switch httpResponse.statusCode {
                    case 200:
                        return (pin, result)
                    case 404:
                        let (result, response) = try await urlSession.data(from: licenseTxtURL)

                        if (response as? HTTPURLResponse)?.statusCode != 404 {
                            return (pin, result)
                        }
                    default: break
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
                        return nil
                    }
                    return (element.0, license)
                }
                .sorted {
                    (dependencies.pins.firstIndex(of: $0.0) ?? 0) < (dependencies.pins.firstIndex(of: $1.0) ?? 0)
                }
                .map { License(identity: $0.0.identity, name: $0.0.name, license: $0.1) }
        }
    }
}
