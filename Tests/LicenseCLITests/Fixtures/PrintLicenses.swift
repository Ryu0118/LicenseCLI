import Foundation

@main
struct PrintLicenses {
    static func main() {
        let ids: [String] = Licenses.all.map(\.id)
        let encoder = JSONEncoder()

        let data = try! encoder.encode(ids)
        print(String(data: data, encoding: .utf8)!)
    }
}
