# LicenseCLI
CLI tool for collecting library licenses

# Installation
### Homebrew
```
brew install ryu0118/tap/licensecli
```
### Mint
```
Ryu0118/LicenseCLI@0.1.0
```

# Usage
```
USAGE: licensecli <project-directory> ... --output-directory <output-directory> [--name <name>]

ARGUMENTS:
  <project-directory>     Directories where Package.swift is located

OPTIONS:
  -o, --output-directory <output-directory>
                          Output directory
  -n, --name <name>       (default: Licenses)
  -h, --help              Show help information.
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
          Text(license.id)
        }
      }
    }
  }
}
```
