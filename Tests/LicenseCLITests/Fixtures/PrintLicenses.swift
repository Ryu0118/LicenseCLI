@main
struct PrintLicenses {
    static func main() {
        let names: [String] = Licenses.all.map(\.name)
        let jsonNames = "[" + names.map { "\"\($0)\"" }.joined(separator: ", ") + "]"
        print(jsonNames)
    }
}
