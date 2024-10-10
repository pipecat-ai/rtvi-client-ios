import Foundation

public struct RTVIURLEndpoints: Codable {
    public let connect: String
    public let action: String
    
    public init() {
        self.init(connect: "/connect", action: "/action")
    }
    
    public init(connect: String = "/connect", action: String = "/action") {
        self.connect = connect
        self.action = action
    }
}
