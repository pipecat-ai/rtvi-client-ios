import Foundation

public struct BotError: Codable {
    public let error: String
    public let fatal: Bool?

    init(error: String, fatal: Bool) {
        self.error = error
        self.fatal = fatal
    }
}
