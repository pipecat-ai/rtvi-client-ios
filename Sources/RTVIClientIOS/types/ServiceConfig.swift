import Foundation

public struct ServiceConfig: Codable {
    public let service: String
    public let options: [Option]
    
    public init(service: String, options: [Option]) {
        self.service = service
        self.options = options
    }
}
