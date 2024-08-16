import Foundation

public struct BotReadyData: Codable {

    public let version: String
    public let config: [ServiceConfig]
    
}
