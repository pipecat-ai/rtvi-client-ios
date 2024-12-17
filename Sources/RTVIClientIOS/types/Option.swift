import Foundation

public struct Option: Codable {
    public let name: String
    public let value: Value
    
    public init(name: String, value: Value) {
        self.name = name
        self.value = value
    }
}
