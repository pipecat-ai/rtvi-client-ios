import Foundation

@MainActor
public protocol VoiceClientHelper: AnyObject {
    init(service: String, voiceClient: VoiceClient)
    
    /// Handle a message received from the backend.
    func handleMessage(msg: VoiceMessageInbound)

    /// Returns a list of message types supported by this helper. Messages received from the backend which have these types will be passed to [handleMessage].
    func getMessageTypes() -> Set<String>
}
