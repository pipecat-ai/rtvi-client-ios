import Foundation

/// An RTVI control message received the by the Transport.
public struct RTVIMessageInbound: Codable {
    
    let id: String?
    let label: String?
    let type: String?
    let data: String?
    let metrics: PipecatMetrics?
    
    /// Messages from the server to the client.
    public enum MessageType {
        /// Bot is connected and ready to receive messages
        public static let BOT_READY = "bot-ready"
        
        /// Received an error response from the server
        public static let ERROR_RESPONSE = "error-response"
        
        /// Received an error from the server
        public static let ERROR = "error"
        
        /// STT transcript (both local and remote) flagged with partial final or sentence
        public static let TRANSCRIPT = "transcript"
        
        /// Get or update config response
        public static let CONFIG_RESPONSE = "config"
        
        /// Configuration options available on the bot
        public static let DESCRIBE_CONFIG_RESPONSE = "config-available"
        
        /// Actions available on the bot
        public static let DESCRIBE_ACTION_RESPONSE = "actions-available"
        
        public static let ACTION_RESPONSE = "action-response"
               
        /// STT transcript from the user
        public static let USER_TRANSCRIPTION = "user-transcription"
        
        /// STT transcript from the bot
        public static let BOT_TRANSCRIPTION = "bot-transcription"
        
        /// User started speaking
        public static let USER_STARTED_SPEAKING = "user-started-speaking"
        
        // User stopped speaking
        public static let USER_STOPPED_SPEAKING = "user-stopped-speaking"
        
        // Bot started speaking
        public static let BOT_STARTED_SPEAKING = "bot-started-speaking"
        
        // Bot stopped speaking
        public static let BOT_STOPPED_SPEAKING = "bot-stopped-speaking"
        
        /// Pipecat metrics
        public static let PIPECAT_METRICS = "pipecat-metrics"
        
        /// LLM transcript from the bot
        public static let BOT_LLM_TEXT = "bot-llm-text"
        /// LLM transcript from the bot has started
        public static let BOT_LLM_STARTED = "bot-llm-started"
        /// LLM transcript from the bot has stopped
        public static let BOT_LLM_STOPPED = "bot-llm-stopped"
        
        /// TTS transcript from the bot
        public static let BOT_TTS_TEXT = "bot-tts-text"
        /// LLM transcript from the bot has started
        public static let BOT_TTS_STARTED = "bot-tts-started"
        /// LLM transcript from the bot has stopped
        public static let BOT_TTS_STTOPED = "bot-tts-stopped"
        
        /// Text has been stored
        public static let STORAGE_ITEM_STORED = "storage-item-stored"
    }

    init(type: String?, data: String?) {
        self.init(type: type, data: data, id: String(UUID().uuidString.prefix(8)), label: "rtvi-ai", metrics: nil)
    }
    
    public init(type: String?, data: String?, id: String?, label: String? = "rtvi-ai", metrics: PipecatMetrics? = nil) {
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




