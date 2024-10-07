import Foundation

/// Configuration options when instantiating a VoiceClient.
public struct RTVIClientOptions: Codable {
    
    /// Connection parameters.
    public let params: RTVIClientParams
    
    /// Enable the user mic input. Defaults to true.
    public let enableMic: Bool
    
    /// Enable user cam input. Defaults to false.
    public let enableCam: Bool
    
    /// A list of services to use on the backend.
    public let services: [String: String]
    
    /// Further configuration options for the backend.
    @available(*, deprecated, message: "Use params.config.")
    public let config: [ServiceConfig]?
    
    /// Custom HTTP headers to be sent with the POST request to baseUrl.
    @available(*, deprecated, message: "Use params.headers.")
    public let customHeaders: [[String: String]]?
    
    /// Custom HTTP body params to be sent with the POST request to baseUrl.
    @available(*, deprecated, message: "Use params.requestData.")
    public let customBodyParams: Value?
    
    public init(
        enableMic: Bool = true,
        enableCam: Bool = false,
        params: RTVIClientParams,
        services: [String: String] = [:],
        config: [ServiceConfig]? = nil,
        customHeaders: [[String: String]]? = nil,
        customBodyParams: Value? = nil
    ) {
        self.enableMic = enableMic
        self.enableCam = enableCam
        self.params = params
        self.services = services
        self.config = config
        self.customHeaders = customHeaders
        self.customBodyParams = customBodyParams
    }
    
}
