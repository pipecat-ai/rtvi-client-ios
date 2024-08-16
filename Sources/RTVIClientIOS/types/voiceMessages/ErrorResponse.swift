import Foundation

public struct ErrorResponse: Codable {
    public let error: String

    init(error: String) {
        self.error = error
    }
}
