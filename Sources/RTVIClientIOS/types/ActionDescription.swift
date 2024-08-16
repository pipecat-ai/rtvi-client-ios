import Foundation

public struct ActionDescription: Codable {
    let service: String
    let action: String
    let arguments: [OptionDescription]
    let result: OptionType
    
    init(service: String, action: String, arguments: [OptionDescription], result: OptionType) {
        self.service = service
        self.action = action
        self.arguments = arguments
        self.result = result
    }
}
