import Foundation

/// An RTVI client. Connects to an RTVI backend and handles bidirectional audio and video.
@MainActor
open class RTVIClient {
    
    private let options: RTVIClientOptions
    private var transport: Transport
    private var baseUrl: String

    private let messageDispatcher: MessageDispatcher
    private var helpers: [String: RegisteredHelper] = [:]
    private var devicesInitialized: Bool = false
    
    private var disconnectRequested: Bool = false
    
    private lazy var onMessage: (RTVIMessageInbound) -> Void = {(voiceMessage: RTVIMessageInbound) in
        guard let type = voiceMessage.type else {
            // Ignoring the message, it doesn't have a type
            return
        }
        Logger.shared.debug("Received voice message \(voiceMessage)")
        switch type {
        case RTVIMessageInbound.MessageType.BOT_READY:
            self.transport.setState(state: .ready)
            if let botReadyData = try? JSONDecoder().decode(BotReadyData.self, from: Data(voiceMessage.data!.utf8)) {
                self.delegate?.onBotReady(botReadyData: botReadyData)
            }
        case RTVIMessageInbound.MessageType.USER_TRANSCRIPTION:
            if let transcript = try? JSONDecoder().decode(Transcript.self, from: Data(voiceMessage.data!.utf8)) {
                self.delegate?.onUserTranscript(data: transcript)
            }
        case RTVIMessageInbound.MessageType.BOT_TRANSCRIPTION:
            if let transcript = try? JSONDecoder().decode(Transcript.self, from: Data(voiceMessage.data!.utf8)) {
                self.delegate?.onBotTranscript(data: transcript.text)
            }
        case RTVIMessageInbound.MessageType.BOT_LLM_TEXT:
            if let botLLMText = try? JSONDecoder().decode(BotLLMText.self, from: Data(voiceMessage.data!.utf8)) {
                self.delegate?.onBotLLMText(data: botLLMText)
            }
        case RTVIMessageInbound.MessageType.BOT_TTS_TEXT:
            if let botTTSText = try? JSONDecoder().decode(BotTTSText.self, from: Data(voiceMessage.data!.utf8)) {
                self.delegate?.onBotTTSText(data: botTTSText)
            }
        case RTVIMessageInbound.MessageType.STORAGE_ITEM_STORED:
            if let storedData = try? JSONDecoder().decode(StorageItemStoredData.self, from: Data(voiceMessage.data!.utf8)) {
                self.delegate?.onStorageItemStored(data: storedData)
            }
        case RTVIMessageInbound.MessageType.PIPECAT_METRICS:
            guard let metrics = voiceMessage.metrics else {
                return
            }
            self.delegate?.onMetrics(data: metrics)
        case RTVIMessageInbound.MessageType.USER_STARTED_SPEAKING:
            self.delegate?.onUserStartedSpeaking()
        case RTVIMessageInbound.MessageType.USER_STOPPED_SPEAKING:
            self.delegate?.onUserStoppedSpeaking()
        case RTVIMessageInbound.MessageType.ACTION_RESPONSE:
            _ = self.messageDispatcher.resolve(message: voiceMessage)
        case RTVIMessageInbound.MessageType.DESCRIBE_ACTION_RESPONSE:
            _ = self.messageDispatcher.resolve(message: voiceMessage)
        case RTVIMessageInbound.MessageType.DESCRIBE_CONFIG_RESPONSE:
            _ = self.messageDispatcher.resolve(message: voiceMessage)
        case RTVIMessageInbound.MessageType.CONFIG_RESPONSE:
            _ = self.messageDispatcher.resolve(message: voiceMessage)
        case RTVIMessageInbound.MessageType.ERROR_RESPONSE:
            Logger.shared.warn("RECEIVED ON ERROR_RESPONSE \(voiceMessage)")
            _ = self.messageDispatcher.reject(message: voiceMessage)
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: Data(voiceMessage.data!.utf8)) {
                self.delegate?.onError(message: errorResponse.error)
            }
        case RTVIMessageInbound.MessageType.ERROR:
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
    private weak var _delegate: RTVIClientDelegate? = nil
    public weak var delegate: RTVIClientDelegate? {
        get {
            return _delegate
        }
        set {
            _delegate = newValue
            self.transport.delegate = _delegate
        }
    }
    
    public init(baseUrl:String? = nil, transport:Transport, options: RTVIClientOptions) {
        Logger.shared.info("Initializing RTVI Client iOS version \(RTVIClient.libraryVersion)")
        
        self.baseUrl = baseUrl ?? options.params.baseUrl
        self.options = options
        self.transport = transport
        
        let headers = options.customHeaders ?? options.params.headers
        let requestData = RTVIClient.appendRtviClientVersion(options.customBodyParams ?? options.params.requestData)
        
        let httpMessageDispatcher = HTTPMessageDispatcher.init(baseUrl: self.baseUrl, endpoints: self.options.params.endpoints, headers: headers, requestData: requestData)
        self.messageDispatcher = MessageDispatcher.init(transport: transport, httpMessageDispatcher: httpMessageDispatcher)
        
        httpMessageDispatcher.onMessage = self.onMessage
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
        if (self.devicesInitialized) {
            // There is nothing to do in this case
            return
        }
        try await self.transport.initDevices()
        self.devicesInitialized = true
    }
    
    private func connectUrl() -> String {
        return self.baseUrl + self.options.params.endpoints.connect
    }
    
    private func fetchAuthBundle() async throws -> AuthBundle {
        guard let url = URL(string: self.connectUrl()) else {
            throw InvalidAuthBundleError()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Adding the custom headers if they have been provided
        let headers = options.customHeaders ?? options.params.headers
        for header in headers {
            for (key, value) in header {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        do {
            let requestData = RTVIClient.appendRtviClientVersion(options.customBodyParams ?? options.params.requestData)
            let config = options.config ?? options.params.config
            if let customBodyParams = requestData {
                var customBundle:Value = try await customBodyParams.convertToRtviValue()
                try customBundle.addProperty(key: "services", value: try await self.options.services.convertToRtviValue())
                try customBundle.addProperty(key: "config", value: try await config.convertToRtviValue())
                request.httpBody = try JSONEncoder().encode( customBundle )
            } else {
                request.httpBody = try JSONEncoder().encode(
                    ConnectionBundle(services: self.options.services, config: config)
                )
            }
            
            Logger.shared.debug("Will request bundle \(String(data: request.httpBody!, encoding: .utf8) ?? "")")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, ( httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 ) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                let message = "Failed while authenticating: \(errorMessage)"
                Logger.shared.error(message)
                throw HttpError(message: message)
            }
            
            return AuthBundle(data: String(data: data, encoding: .utf8)!)
        } catch {
            Logger.shared.error(error.localizedDescription)
            throw HttpError(message: "Failed while authenticating.", underlyingError: error)
        }
    }
    
    /// Initiate an RTVI session, connecting to the backend.
    public func start() async throws {
        do {
            self.disconnectRequested = false
            if(!self.devicesInitialized) {
                try await self.initDevices()
            }
            
            if(self.bailIfDisconnected()) {
                return
            }
            
            self.transport.setState(state: .authenticating)
            // Send POST request to the provided baseUrl to connect and start the bot
            let authBundle = try await fetchAuthBundle()
            
            if(self.bailIfDisconnected()) {
                return
            }
            
            try await self.transport.connect(authBundle: authBundle)
            
            if(self.bailIfDisconnected()) {
                return
            }
        } catch {
            self.disconnect(completion: nil)
            self.transport.setState(state: .disconnected)
            throw StartBotError(underlyingError: error)
        }
    }
    
    private func bailIfDisconnected() -> Bool {
        if (self.disconnectRequested) {
            if (self.transport.state() != .disconnecting && self.transport.state() != .disconnected) {
                self.disconnect(completion: nil)
            }
            return true
        }
        return false
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
    func sendMessage(msg: RTVIMessageOutbound) async throws {
        try await self.transport.sendMessage(message: msg)
    }
    
    /// Directly send a message to the bot via the transport.
    func sendMessage(msg: RTVIMessageOutbound, completion: ((Result<Void, AsyncExecutionError>) -> Void)?) {
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
        self.transport.setState(state: .disconnecting)
        self.disconnectRequested = true
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
    
    /// Check if the transport is connected
    public func isConnected() -> Bool {
        return self.transport.isConnected()
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
        let voiceMessageResponse = try await self.messageDispatcher.dispatchAsync(message: RTVIMessageOutbound.getConfig())
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
        let voiceMessageResponse = try await self.messageDispatcher.dispatchAsync(message: RTVIMessageOutbound.describeConfig())
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
    public func updateConfig(config: [ServiceConfig], interrupt: Bool = false) async throws -> ConfigResponse {
        try self.assertReady()
        let voiceMessageResponse =  try await self.messageDispatcher.dispatchAsync(message: RTVIMessageOutbound.updateConfig(config: config, interrupt: interrupt))
        let configResponse = try JSONDecoder().decode(ConfigResponse.self, from: Data(voiceMessageResponse.data!.utf8))
        self.delegate?.onConfigUpdated(config: configResponse.config)
        return configResponse
    }
    
    /// Updates the config on the server.
    public func updateConfig(config: [ServiceConfig], interrupt: Bool = false, completion: ((Result<ConfigResponse, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                let configDescription = try await self.updateConfig(config:config, interrupt: interrupt)
                completion?(.success((configDescription)))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "updateConfig", underlyingError: error)))
            }
        }
    }
    
    /// Dispatch an action message to the bot
    public func action<T: Decodable>(action: ActionRequest, resultType: T.Type, unwrapResult: Bool = true) async throws -> T {
        let voiceMessageResponse =  try await self.messageDispatcher.dispatchAsync(message: RTVIMessageOutbound.action(actionData: action))
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
        let voiceMessageResponse = try await self.messageDispatcher.dispatchAsync(message: RTVIMessageOutbound.describeActions())
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
    public func registerHelper<T: RTVIClientHelper>(service: String, helper: T.Type) throws -> T {
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
    public func getHelper<T: RTVIClientHelper>(service: String) throws -> T {
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
