import Foundation

public struct BotError: Codable {
    public let message: String

    init(message: String) {
        self.message = message
    }
}
