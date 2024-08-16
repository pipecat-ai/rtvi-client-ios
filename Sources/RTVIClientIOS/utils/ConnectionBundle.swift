import Foundation

public struct ConnectionBundle: Codable {
    let services: [String: String]
    let config: [ServiceConfig]
    
    init(services: [String : String], config: [ServiceConfig]) {
        self.services = services
        self.config = config
    }
}
