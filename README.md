# LicenseCLI
CLI tool for collecting library licenses

# Installation
### Mint
```
Ryu0118/LicenseList@0.0.1
```

# Usage
```
USAGE: licensecli <project-directory> <output-directory> [--name <name>]

ARGUMENTS:
  <project-directory>     Directory where Package.swift is located
  <output-directory>      Output directory

OPTIONS:
  -n, --name <name>       Name of the generated Swift file
  -h, --help              Show help information.
```

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
