import Foundation

public struct DescribeConfigResponse: Codable {
    public let config: [ServiceConfigDescription]
    
    init(config: [ServiceConfigDescription]) {
        self.config = config
    }
}
