import ArgumentParser
@testable import LicenseCLI
@testable import LicenseCLICore
import Testing

@Suite
struct GenerateValidationTests {
    private func makeCommand(noCache: Bool, cacheDir: String?) -> Generate {
        var command = Generate()
        command.noCache = noCache
        command.packageDepsCacheDir = cacheDir
        return command
    }

    @Test
    func cacheLocationDefaultsToGlobal() {
        #expect(makeCommand(noCache: false, cacheDir: nil).cacheLocation == .global)
    }

    @Test
    func customCacheDirSelectsCustomLocation() {
        let command = makeCommand(noCache: false, cacheDir: "/tmp/cache")
        #expect(command.cacheLocation == .custom(path: "/tmp/cache"))
    }

    @Test
    func noCacheSelectsDisabledLocation() {
        #expect(makeCommand(noCache: true, cacheDir: nil).cacheLocation == .disabled)
    }

    @Test
    func noCacheAndCustomCacheDirAreMutuallyExclusive() throws {
        // The conflict check runs before logging is bootstrapped, so calling validate()
        // here does not initialize the (once-per-process) logging system.
        var command = makeCommand(noCache: true, cacheDir: "/tmp/cache")
        #expect(throws: ValidationError.self) {
            try command.validate()
        }
    }
}
