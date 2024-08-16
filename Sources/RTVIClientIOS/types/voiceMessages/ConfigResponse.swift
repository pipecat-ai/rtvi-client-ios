import Foundation

public struct ConfigResponse: Codable {
    public let config: [ServiceConfig]

    init(config: [ServiceConfig]) {
        self.config = config
    }
}
