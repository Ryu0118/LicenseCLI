import Foundation

enum GitOperationsError: LocalizedError {
    case gitNotAvailable
    case cloneFailed(String)
    case checkoutFailed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .gitNotAvailable:
            return "git command is not available. Please install git."
        case .cloneFailed(let message):
            return "Failed to clone repository: \(message)"
        case .checkoutFailed(let message):
            return "Failed to checkout version: \(message)"
        case .commandFailed(let message):
            return "Git command failed: \(message)"
        }
    }
}

enum GitOperations {
    /// Check if git is available on the system
    static func isGitAvailable() -> Bool {
        do {
            _ = try Command.run(
                launchPath: "/usr/bin/which",
                arguments: ["git"]
            )
            return true
        } catch {
            return false
        }
    }

    /// Clone a repository to the specified destination
    /// Uses shallow clone (--depth 1) for better performance
    static func clone(repoURL: String, to destination: URL, reference: String? = nil) throws {
        logger.info("Cloning repository: \(repoURL)")

        var arguments = ["clone"]

        // If a specific reference is provided and it's not HEAD, use --branch
        if let reference = reference, reference != "HEAD" {
            arguments.append(contentsOf: ["--branch", reference])
        }

        arguments.append(contentsOf: [repoURL, destination.path])

        do {
            try Command.run(
                launchPath: "/usr/bin/git",
                arguments: arguments
            )
            logger.info("Successfully cloned repository to \(destination.path)")
        } catch {
            throw GitOperationsError.cloneFailed("Failed to clone \(repoURL): \(error.localizedDescription)")
        }
    }

    /// Checkout a specific reference (branch, tag, or commit)
    static func checkout(reference: String, at directory: URL) throws {
        logger.info("Checking out reference: \(reference)")

        do {
            try Command.run(
                launchPath: "/usr/bin/git",
                currentDirectoryPath: directory.path,
                arguments: ["checkout", reference]
            )
            logger.info("Successfully checked out \(reference)")
        } catch {
            throw GitOperationsError.checkoutFailed("Failed to checkout \(reference): \(error.localizedDescription)")
        }
    }

    /// Get the current branch name
    static func getCurrentBranch(at directory: URL) throws -> String {
        do {
            let output = try Command.run(
                launchPath: "/usr/bin/git",
                currentDirectoryPath: directory.path,
                arguments: ["rev-parse", "--abbrev-ref", "HEAD"]
            )
            return output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "HEAD"
        } catch {
            throw GitOperationsError.commandFailed("Failed to get current branch: \(error.localizedDescription)")
        }
    }

    /// Get the current revision (commit SHA) of the repository
    static func getCurrentRevision(at directory: URL) throws -> String? {
        do {
            let output = try Command.run(
                launchPath: "/usr/bin/git",
                currentDirectoryPath: directory.path,
                arguments: ["rev-parse", "HEAD"]
            )
            return output?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw GitOperationsError.commandFailed("Failed to get current revision: \(error.localizedDescription)")
        }
    }

    /// Check if a directory is a git repository
    static func isGitRepository(at directory: URL) -> Bool {
        let gitDir = directory.appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitDir.path) || FileManager.default.fileExists(atPath: directory.path + "/.git")
    }

    /// Get the revision for a specific reference (branch, tag, or commit)
    static func getRevision(for reference: String, at directory: URL) throws -> String? {
        do {
            let output = try Command.run(
                launchPath: "/usr/bin/git",
                currentDirectoryPath: directory.path,
                arguments: ["rev-parse", reference]
            )
            return output?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw GitOperationsError.commandFailed("Failed to get revision for \(reference): \(error.localizedDescription)")
        }
    }
}
