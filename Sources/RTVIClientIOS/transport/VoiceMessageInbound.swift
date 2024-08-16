import Foundation

/// An RTVI control message received the by the Transport.
public struct VoiceMessageInbound: Codable {
    
    let id: String?
    let label: String?
    let type: String?
    let data: String?
    let metrics: PipecatMetrics?
    
    /// Messages from the server to the client.
    public enum MessageType {
        /// Bot is connected and ready to receive messages
        static let BOT_READY = "bot-ready"
        
        /// Received an error response from the server
        static let ERROR_RESPONSE = "error-response"
        
        /// Received an error from the server
        static let ERROR = "error"
        
        /// STT transcript (both local and remote) flagged with partial final or sentence
        static let TRANSCRIPT = "transcript"
        
        /// Get or update config response
        static let CONFIG_RESPONSE = "config"
        
        /// Configuration options available on the bot
        static let DESCRIBE_CONFIG_RESPONSE = "config-available"
        
        /// Actions available on the bot
        static let DESCRIBE_ACTION_RESPONSE = "actions-available"
        
        static let ACTION_RESPONSE = "action-response"
               
        /// STT transcript from the user
        static let USER_TRANSCRIPTION = "user-transcription"
        
        /// STT transcript from the bot
        static let BOT_TRANSCRIPTION = "tts-text"
        
        // User started speaking
        static let USER_STARTED_SPEAKING = "user-started-speaking"
        
        // User stopped speaking
        static let USER_STOPPED_SPEAKING = "user-stopped-speaking"
        
        // Bot started speaking
        static let BOT_STARTED_SPEAKING = "bot-started-speaking"
        
        // Bot stopped speaking
        static let BOT_STOPPED_SPEAKING = "bot-stopped-speaking"
        
        // Pipecat metrics
        static let PIPECAT_METRICS = "pipecat-metrics"
    }

    init(type: String?, data: String?) {
        self.init(type: type, data: data, id: String(UUID().uuidString.prefix(8)), label: "rtvi-ai", metrics: nil)
    }
    
    init(type: String?, data: String?, id: String?, label: String?, metrics: PipecatMetrics?) {
        self.id = id
        self.label = label
        self.type = type
        self.data = data
        self.metrics = metrics
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case label
        case type
        case data
        case metrics
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let type = try container.decode(String.self, forKey: .type)
        
        let datavalue = try? container.decodeIfPresent(Value.self, forKey: .data)
        let data: String?
        if(datavalue != nil) {
            data = try? String(data: JSONEncoder().encode(datavalue), encoding: .utf8)
        }else {
            data = nil
        }
        
        let metrics = try? container.decodeIfPresent(PipecatMetrics.self, forKey: .metrics)
        
        let label = try? container.decodeIfPresent(String.self, forKey: .label)
        let id = try? container.decodeIfPresent(String.self, forKey: .id)
        
        self.init(type: type, data: data, id: id, label: label, metrics: metrics)
    }
}




