internal class RegisteredHelper {
    let helper: VoiceClientHelper
    let supportedMessages: Set<String>

    init(helper: VoiceClientHelper, supportedMessages: Set<String>) {
        self.helper = helper
        self.supportedMessages = supportedMessages
    }
}
