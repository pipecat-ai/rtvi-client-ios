import Foundation

/// A written transcript of some spoken words.
public struct Transcript: Codable {
    public let text: String
    public let final: Bool?
    public let timestamp: String?
    public let userId: String?

    enum CodingKeys: String, CodingKey {
        case text
        case final
        case timestamp
        case userId = "user_id"
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try container.decode(String.self, forKey: .text)
        self.final = try container.decodeIfPresent(Bool.self, forKey: .final)
        self.timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        self.userId = try container.decodeIfPresent(String.self, forKey: .userId)
    }
}
