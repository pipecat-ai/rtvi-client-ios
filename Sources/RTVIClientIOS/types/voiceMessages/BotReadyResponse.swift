import Foundation

public struct BotReadyData: Codable {

    public let version: String
    public let config: [ServiceConfig]
    
    public init(version: String, config: [ServiceConfig]) {
        self.version = version
        self.config = config
    }
}
