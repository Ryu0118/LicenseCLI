import Foundation

public struct License: Equatable {
    public let identity: String
    public let license: String

    public init(identity: String, license: String) {
        self.identity = identity
        self.license = license
    }
}
