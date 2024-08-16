import Foundation

public typealias Argument = Option

public struct ActionRequest: Codable {
    
    let service: String
    let action: String
    let arguments: [Argument]?
    
    public init(service: String, action: String, arguments: [Option]?=nil) {
        self.service = service
        self.action = action
        self.arguments = arguments
    }
    
}
