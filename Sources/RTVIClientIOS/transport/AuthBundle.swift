import Foundation

/// A bundle of initialization data received from the RTVI backend.
public struct AuthBundle: Decodable {
    public let data: String
}
