import Foundation

/// An RTVI transport.
@MainActor
public protocol Transport {
    init(options: VoiceClientOptions)
    var delegate: VoiceClientDelegate? { get set }
    var onMessage: ((VoiceMessageInbound) -> Void)? { get set }
    
    func initDevices() async throws
    func release()
    func connect(authBundle: AuthBundle) async throws
    func disconnect() async throws
    func getAllMics() -> [MediaDeviceInfo]
    func getAllCams() -> [MediaDeviceInfo]
    func updateMic(micId: MediaDeviceId) async throws
    func updateCam(camId: MediaDeviceId) async throws
    func selectedMic() -> MediaDeviceInfo?
    func selectedCam() -> MediaDeviceInfo?
    func enableMic(enable: Bool) async throws
    func enableCam(enable: Bool) async throws
    func isCamEnabled() -> Bool
    func isMicEnabled() -> Bool
    func sendMessage(message: VoiceMessageOutbound) throws
    func state() -> TransportState
    func setState(state: TransportState)
    func tracks() -> Tracks?
}
