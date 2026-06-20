# LicenseCLI
CLI tool for collecting library licenses

# Installation
### nest
The easiest way to install LicenseCLI is to use [nest](https://github.com/mtj0928/nest). 
`nest install Ryu0118/LicenseCLI`

### Mint
```
Ryu0118/LicenseCLI@0.2.1
```

# Usage
```
USAGE: licensecli <subcommand>

OPTIONS:
  -h, --help              Show help information.

SUBCOMMANDS:
  generate (default)      Generate a license file (default command)
  cache-prune             Remove all cached package dependency clones
```

### `generate` (default)
```
USAGE: licensecli generate [<project-directory> ...] [--github-repo <github-repo> ...] [--package-deps <package-deps> ...] --output-directory <output-directory> [--name <name>] [--verbose]

ARGUMENTS:
  <project-directory>     Directories where Package.swift is located

OPTIONS:
  --github-repo <github-repo>
                          GitHub repository URLs (e.g., https://github.com/owner/repo)
  --package-deps <package-deps>
                          GitHub repository URLs with dependencies (e.g., https://github.com/owner/repo@1.0.0)
  -o, --output-directory <output-directory>
                          Output directory
  -n, --name <name>       (default: Licenses)
  --verbose               Enable verbose logging
  -h, --help              Show help information.
```

`generate` is the default subcommand, so `licensecli --output-directory ...` works the same as `licensecli generate --output-directory ...`.

### Package dependency cache

Clones used by `--package-deps` are cached in a global, project-shared directory
(`~/Library/Caches/LicenseCLI` on macOS, `~/.cache/LicenseCLI` on Linux) and reused
across runs, keyed by `owner-name@version`. Entries unused for more than 30 days are
pruned automatically. To clear the cache manually:

```
licensecli cache-prune
```

When you execute LicenseCLI, it generates `Licenses`. `Licenses` contain an `all` property, which stores the licenses of all dependencies used by the package.
This is the Example code for use with SwiftUI:

```Swift
public struct LicenseView: View {
  public var body: some View {
    List {
      ForEach(Licenses.all) { license in
        NavigationLink {
          ScrollView {
            Text(license.license)
          }
        } label: {
          Text(license.name)
        }
      }
    }
  }
}
```
