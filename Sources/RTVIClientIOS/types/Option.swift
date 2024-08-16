import Foundation

public struct Option: Codable {
    let name: String
    let value: Value
    
    public init(name: String, value: Value) {
        self.name = name
        self.value = value
    }
}
