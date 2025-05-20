import Foundation

public struct License: Equatable {
    public let identity: String
    public let name: String
    public let license: String

    public init(identity: String, name: String, license: String) {
        self.identity = identity
        self.name = name
        self.license = license
    }
}
