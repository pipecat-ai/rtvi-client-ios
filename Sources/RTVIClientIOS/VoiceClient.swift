import Foundation

/// An RTVI client. Connects to an RTVI backend and handles bidirectional audio and video.
@MainActor
open class VoiceClient {
    
    private let options: VoiceClientOptions
    private var transport: Transport
    private let baseUrl: String
    private let messageDispatcher: MessageDispatcher
    private var helpers: [String: RegisteredHelper] = [:]
    
    private lazy var onMessage: (VoiceMessageInbound) -> Void = {(voiceMessage: VoiceMessageInbound) in
        guard let type = voiceMessage.type else {
            // Ignoring the message, it doesn't have a type
            return
        }
        Logger.shared.debug("Received voice message \(voiceMessage)")
        switch type {
        case VoiceMessageInbound.MessageType.BOT_READY:
            self.transport.setState(state: .ready)
            if let botReadyData = try? JSONDecoder().decode(BotReadyData.self, from: Data(voiceMessage.data!.utf8)) {
                self.delegate?.onBotReady(botReadyData: botReadyData)
            }
        case VoiceMessageInbound.MessageType.USER_TRANSCRIPTION:
            if let transcript = try? JSONDecoder().decode(Transcript.self, from: Data(voiceMessage.data!.utf8)) {
                self.delegate?.onUserTranscript(data: transcript)
            }
        case VoiceMessageInbound.MessageType.BOT_TRANSCRIPTION:
            if let transcript = try? JSONDecoder().decode(Transcript.self, from: Data(voiceMessage.data!.utf8)) {
                self.delegate?.onBotTranscript(data: transcript.text)
            }
        case VoiceMessageInbound.MessageType.PIPECAT_METRICS:
            guard let metrics = voiceMessage.metrics else {
                return
            }
            self.delegate?.onMetrics(data: metrics)
        case VoiceMessageInbound.MessageType.USER_STARTED_SPEAKING:
            self.delegate?.onUserStartedSpeaking()
        case VoiceMessageInbound.MessageType.USER_STOPPED_SPEAKING:
            self.delegate?.onUserStoppedSpeaking()
        case VoiceMessageInbound.MessageType.ACTION_RESPONSE:
            _ = self.messageDispatcher.resolve(message: voiceMessage)
        case VoiceMessageInbound.MessageType.DESCRIBE_ACTION_RESPONSE:
            _ = self.messageDispatcher.resolve(message: voiceMessage)
        case VoiceMessageInbound.MessageType.DESCRIBE_CONFIG_RESPONSE:
            _ = self.messageDispatcher.resolve(message: voiceMessage)
        case VoiceMessageInbound.MessageType.CONFIG_RESPONSE:
            _ = self.messageDispatcher.resolve(message: voiceMessage)
        case VoiceMessageInbound.MessageType.ERROR_RESPONSE:
            Logger.shared.warn("RECEIVED ON ERROR_RESPONSE \(voiceMessage)")
            _ = self.messageDispatcher.reject(message: voiceMessage)
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: Data(voiceMessage.data!.utf8)) {
                self.delegate?.onError(message: errorResponse.error)
            }
        case VoiceMessageInbound.MessageType.ERROR:
            Logger.shared.warn("RECEIVED ON ERROR \(voiceMessage)")
            _ = self.messageDispatcher.reject(message: voiceMessage)
            if let botError = try? JSONDecoder().decode(BotError.self, from: Data(voiceMessage.data!.utf8)) {
                let errorMessage = "Received a fatal error from the Bot: \(botError.error)"
                self.delegate?.onError(message: errorMessage)
                if(botError.fatal ?? false) {
                    self.disconnect(completion: nil)
                }
            }
        default:
            // Check if we have handlers to deal with the message
            var match = false
            for entry in self.helpers.values where entry.supportedMessages.contains(type) {
                match = true
                entry.helper.handleMessage(msg: voiceMessage)
            }
            if !match {
                Logger.shared.debug("Unexpected message type: \(type), message: \(voiceMessage)")
                self.delegate?.onGenericMessage(message: voiceMessage)
            }
        }
    }
    
    /// The object that acts as the delegate of the voice client.
    private weak var _delegate: VoiceClientDelegate? = nil
    public weak var delegate: VoiceClientDelegate? {
        get {
            return _delegate
        }
        set {
            _delegate = newValue
            self.transport.delegate = _delegate
        }
    }
    
    public init(baseUrl:String, transport:Transport, options: VoiceClientOptions) {
        self.baseUrl = baseUrl
        self.options = options
        self.transport = transport
        self.messageDispatcher = MessageDispatcher.init(transport: transport)
        self.transport.onMessage = self.onMessage
    }
    
    /// Initialize local media devices such as camera and microphone.
    public func initDevices(completion: ((Result<Void, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                try await self.initDevices()
                completion?(.success(()))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "initDevices", underlyingError: error)))
            }
        }
    }
    
    /// Initialize local media devices such as camera and microphone.
    public func initDevices() async throws {
        try await self.transport.initDevices()
    }
    
    private func fetchAuthBundle() async throws -> AuthBundle {
        guard let url = URL(string: self.baseUrl) else {
            throw InvalidAuthBundleError()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Adding the custom headers if they have been provided
        for header in self.options.customHeaders {
            for (key, value) in header {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        do {
            if let customBodyParams = options.customBodyParams {
                var customBundle:Value = try await customBodyParams.convertToRtviValue()
                try customBundle.addProperty(key: "services", value: try await self.options.services.convertToRtviValue())
                try customBundle.addProperty(key: "config", value: try await self.options.config.convertToRtviValue())
                request.httpBody = try JSONEncoder().encode( customBundle )

            } else {
                request.httpBody = try JSONEncoder().encode(
                    ConnectionBundle(services: self.options.services, config: self.options.config)
                )
            }
            
            Logger.shared.debug("Will request bundle \(String(data: request.httpBody!, encoding: .utf8) ?? "")")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw FetchAuthBundleError()
            }
            
            return AuthBundle(data: String(data: data, encoding: .utf8)!)
        } catch {
            throw FetchAuthBundleError(underlyingError: error)
        }
    }
    
    /// Initiate an RTVI session, connecting to the backend.
    public func start() async throws {
        do {
            if(self.transport.state() == .idle) {
                try await self.initDevices()
            }
            
            self.transport.setState(state: .handshaking)
            
            // Send POST request to the provided baseUrl to connect and start the bot
            let authBundle = try await fetchAuthBundle()
            try await self.transport.connect(authBundle: authBundle)
        } catch {
            self.disconnect(completion: nil)
            self.transport.setState(state: .disconnected)
            throw StartBotError(underlyingError: error)
        }
    }
    
    /// Initiate an RTVI session, connecting to the backend.
    public func start(completion: ((Result<Void, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                try await self.start()
                completion?(.success(()))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "start", underlyingError: error)))
            }
        }
    }
    
    /// Directly send a message to the bot via the transport.
    func sendMessage(msg: VoiceMessageOutbound) async throws {
        try await self.transport.sendMessage(message: msg)
    }
    
    /// Directly send a message to the bot via the transport.
    func sendMessage(msg: VoiceMessageOutbound, completion: ((Result<Void, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                try await self.sendMessage(msg: msg)
                completion?(.success(()))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "sendMessage", underlyingError: error)))
            }
        }
    }
    
    /// Disconnect an active RTVI session.
    public func disconnect() async throws {
        try await self.transport.disconnect()
    }
    
    /// Disconnect an active RTVI session.
    public func disconnect(completion: ((Result<Void, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                try await self.disconnect()
                completion?(.success(()))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "disconnect", underlyingError: error)))
            }
        }
    }
    
    /// The current state of the session.
    public var state: TransportState {
        self.transport.state()
    }
    
    /// Returns a list of available audio input devices.
    public func getAllMics() -> [MediaDeviceInfo] {
        return self.transport.getAllMics()
    }
    
    /// Returns a list of available video input devices.
    public func getAllCams() -> [MediaDeviceInfo] {
        self.transport.getAllCams()
    }
    
    /// Returns the selected audio input device.
    public var selectedMic: MediaDeviceInfo? {
        return self.transport.selectedMic()
    }
    
    /// Returns the selected video input device.
    public var selectedCam: MediaDeviceInfo? {
        return self.transport.selectedCam()
    }
    
    /// Use the specified audio input device.
    public func updateMic(micId: MediaDeviceId) async throws {
        try await self.transport.updateMic(micId: micId)
    }
    
    /// Use the specified audio input device.
    public func updateMic(micId: MediaDeviceId, completion: ((Result<Void, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                try await self.updateMic(micId: micId)
                completion?(.success(()))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "updateMic", underlyingError: error)))
            }
        }
    }
    
    /// Use the specified video input device.
    public func updateCam(camId: MediaDeviceId) async throws {
        try await self.transport.updateCam(camId: camId)
    }
    
    /// Use the specified video input device.
    public func updateCam(camId: MediaDeviceId, completion: ((Result<Void, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                try await self.updateCam(camId: camId)
                completion?(.success(()))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "updateCam", underlyingError: error)))
            }
        }
    }
    
    /// Enables or disables the audio input device.
    public func enableMic(enable: Bool) async throws {
        try await self.transport.enableMic(enable: enable)
    }
    
    /// Enables or disables the audio input device.
    public func enableMic(enable: Bool, completion: ((Result<Void, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                try await self.enableMic(enable: enable)
                completion?(.success(()))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "enableMic", underlyingError: error)))
            }
        }
    }
    
    /// Enables or disables the video input device.
    public func enableCam(enable: Bool) async throws {
        try await self.transport.enableCam(enable: enable)
    }
    
    /// Enables or disables the video input device.
    public func enableCam(enable: Bool, completion: ((Result<Void, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                try await self.enableCam(enable: enable)
                completion?(.success(()))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "enableCam", underlyingError: error)))
            }
        }
    }
    
    /// Returns true if the microphone is enabled, false otherwise.
    public var isMicEnabled: Bool {
        self.transport.isMicEnabled()
    }
    
    /// Returns true if the camera is enabled, false otherwise.
    public var isCamEnabled: Bool {
        self.transport.isCamEnabled()
    }
    
    /// Returns a list of participant media tracks.
    var tracks: Tracks? {
        return self.transport.tracks()
    }
    
    /// Request the bot to send its current configuration
    public func getConfig() async throws -> ConfigResponse {
        try self.assertReady()
        let voiceMessageResponse = try await self.messageDispatcher.dispatchAsync(message: VoiceMessageOutbound.getConfig())
        let configResponse = try JSONDecoder().decode(ConfigResponse.self, from: Data(voiceMessageResponse.data!.utf8))
        self.delegate?.onConfigUpdated(config: configResponse.config)
        return configResponse
    }
    
    /// Request the bot to send its current configuration
    public func getConfig(completion: ((Result<ConfigResponse, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                let config = try await self.getConfig()
                completion?(.success((config)))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "getConfig", underlyingError: error)))
            }
        }
    }
    
    /// Request the bot to describe its current configuration
    public func describeConfig() async throws -> DescribeConfigResponse {
        try self.assertReady()
        let voiceMessageResponse = try await self.messageDispatcher.dispatchAsync(message: VoiceMessageOutbound.describeConfig())
        let describedConfig = try JSONDecoder().decode(DescribeConfigResponse.self, from: Data(voiceMessageResponse.data!.utf8))
        self.delegate?.onConfigDescribed(config: describedConfig.config)
        return describedConfig
    }
    
    /// Request the bot to describe its current configuration
    public func describeConfig(completion: ((Result<DescribeConfigResponse, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                let configDescription = try await self.describeConfig()
                completion?(.success((configDescription)))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "describeConfig", underlyingError: error)))
            }
        }
    }
    
    /// Updates the config on the server.
    public func updateConfig(config: [ServiceConfig]) async throws -> ConfigResponse {
        try self.assertReady()
        let voiceMessageResponse =  try await self.messageDispatcher.dispatchAsync(message: VoiceMessageOutbound.updateConfig(config: config))
        let configResponse = try JSONDecoder().decode(ConfigResponse.self, from: Data(voiceMessageResponse.data!.utf8))
        self.delegate?.onConfigUpdated(config: configResponse.config)
        return configResponse
    }
    
    /// Updates the config on the server.
    public func updateConfig(config: [ServiceConfig], completion: ((Result<ConfigResponse, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                let configDescription = try await self.updateConfig(config:config)
                completion?(.success((configDescription)))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "updateConfig", underlyingError: error)))
            }
        }
    }
    
    /// Dispatch an action message to the bot
    public func action<T: Decodable>(action: ActionRequest, resultType: T.Type, unwrapResult: Bool = true) async throws -> T {
        try self.assertReady()
        let voiceMessageResponse =  try await self.messageDispatcher.dispatchAsync(message: VoiceMessageOutbound.action(actionData: action))
        if unwrapResult {
            return (try JSONDecoder().decode(ActionResponseWrapper<T>.self, from: Data(voiceMessageResponse.data!.utf8))).result
        } else {
            return try JSONDecoder().decode(resultType, from: Data(voiceMessageResponse.data!.utf8))
        }
    }
    
    /// Dispatch an action message to the bot
    public func action(action: ActionRequest) async throws -> ActionResponse {
        try await self.action(action:action, resultType: ActionResponse.self, unwrapResult: false)
    }
    
    /// Dispatch an action message to the bot
    public func action(action: ActionRequest, completion: ((Result<ActionResponse, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                let configDescription = try await self.action(action:action)
                completion?(.success((configDescription)))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "action", underlyingError: error)))
            }
        }
    }
    
    /// Describe available / registered actions the bot has
    public func describeActions() async throws -> DescribeActionResponse {
        try self.assertReady()
        let voiceMessageResponse = try await self.messageDispatcher.dispatchAsync(message: VoiceMessageOutbound.describeActions())
        let describedActions = try JSONDecoder().decode(DescribeActionResponse.self, from: Data(voiceMessageResponse.data!.utf8))
        self.delegate?.onActionsAvailable(actions: describedActions.actions)
        return describedActions
    }
    
    /// Describe available / registered actions the bot has
    public func describeActions(completion: ((Result<DescribeActionResponse, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                let actionDescription = try await self.describeActions()
                completion?(.success((actionDescription)))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "describeActions", underlyingError: error)))
            }
        }
    }
    
    /// Registers a new helper with the client.
    public func registerHelper<T: VoiceClientHelper>(service: String, helper: T.Type) throws -> T {
        if helpers.keys.contains(service) {
            throw OtherError(message: "Helper with name '\(service)' already registered")
        }
        
        let clientHelper = helper.init(service: service, voiceClient: self)
        let entry = RegisteredHelper(
            helper: clientHelper,
            supportedMessages: Set(clientHelper.getMessageTypes())
        )
        
        helpers[service] = entry
        
        return clientHelper
    }
    
    /// Unregisters a helper from the client.
    public func unregisterHelper(service: String) throws {
        if !helpers.keys.contains(service) {
            throw OtherError(message: "Helper with name '\(service)' not registered")
        }
        _ = helpers.removeValue(forKey: service)
    }
    
    /// Retrieves a helper from the client.
    public func getHelper<T: VoiceClientHelper>(service: String) throws -> T {
        guard let entry = helpers[service] else {
            throw OtherError(message: "Helper with name '\(service)' not registered")
        }
        
        guard let helper = entry.helper as? T else {
            throw OtherError(message: "Helper registered for service '\(service)' is not of expected type")
        }
        
        return helper
    }
    
    /// Destroys this VoiceClient and cleans up any allocated resources.
    public func release() {
        self.transport.release()
    }
    
    /// The expiry time for the transport session, if applicable. Measured in seconds since the UNIX epoch (UTC).
    public func expiry() -> Int? {
        self.transport.expiry()
    }
    
    func assertReady() throws -> Void{
        if self.state != .ready {
            throw BotNotReadyError()
        }
    }
}
