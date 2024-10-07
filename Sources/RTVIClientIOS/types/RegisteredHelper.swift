internal class RegisteredHelper {
    let helper: RTVIClientHelper
    let supportedMessages: Set<String>

    init(helper: RTVIClientHelper, supportedMessages: Set<String>) {
        self.helper = helper
        self.supportedMessages = supportedMessages
    }
}
