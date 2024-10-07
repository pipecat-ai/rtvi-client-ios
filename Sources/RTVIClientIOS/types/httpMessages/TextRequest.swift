import Foundation

public struct TextRequest: Encodable {
    let actions: [RTVIMessageOutbound]
    
    init(action: RTVIMessageOutbound) {
        self.actions = [action]
    }
    
    enum CodingKeys: String, CodingKey {
        case actions
    }
}
