/// Configuration params when instantiating a RTVIClient.
public struct RTVIClientParams: Codable {
    
    /// The base URL for the RTVI POST request.
    /// Not needed when using certain transports that don't communicate with an RTVI server.
    public let baseUrl: String?
    
    /// Custom HTTP headers to be sent with the POST request to baseUrl.
    public let headers: [[String: String]]
    
    /// API endpoint names for the RTVI POST requests.
    public let endpoints: RTVIURLEndpoints
    
    /// Custom parameters to add to the auth request body.
    public let requestData: Value?
    
    /// Further configuration options for the backend.
    public let config: [ServiceConfig]
    
    public init(
        baseUrl: String? = nil,
        headers: [[String: String]] = [],
        endpoints: RTVIURLEndpoints = RTVIURLEndpoints(),
        requestData: Value? = nil,
        config: [ServiceConfig] = []
    ) {
        self.baseUrl = baseUrl
        self.headers = headers
        self.endpoints = endpoints
        self.requestData = requestData
        self.config = config
    }
    
}
