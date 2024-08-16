import Foundation

public struct OptionDescription: Codable {
    let name: String
    let type: OptionType
    
    public init(name: String, type: OptionType) {
        self.name = name
        self.type = type
    }
}
