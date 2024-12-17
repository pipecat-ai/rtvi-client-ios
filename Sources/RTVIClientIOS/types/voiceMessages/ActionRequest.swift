import Foundation

public typealias Argument = Option

public struct ActionRequest: Codable {
    
    public let service: String
    public let action: String
    public let arguments: [Argument]?
    
    public init(service: String, action: String, arguments: [Option]?=nil) {
        self.service = service
        self.action = action
        self.arguments = arguments
    }
    
}
