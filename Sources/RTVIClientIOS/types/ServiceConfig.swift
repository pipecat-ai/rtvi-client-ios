import Foundation

public struct ServiceConfig: Codable {
    let service: String
    let options: [Option]
    
    public init(service: String, options: [Option]) {
        self.service = service
        self.options = options
    }
}
