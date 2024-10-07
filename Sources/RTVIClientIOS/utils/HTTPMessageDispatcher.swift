import Foundation

/// Helper class for sending messages to the server through HTTP and awaiting the response.
class HTTPMessageDispatcher {
    
    private let baseUrl: String
    
    private let endpoints: RTVIURLEndpoints
    
    /// Custom HTTP headers to be sent with the POST request to baseUrl.
    public let headers: [[String: String]]
    
    /// Custom HTTP body params to be sent with the POST request to baseUrl.
    public let requestData: Value?
    
    // callback for the messages that we are going to receive from the HTTP
    public var onMessage: ((RTVIMessageInbound) -> Void)? = nil
    
    init(baseUrl: String, endpoints: RTVIURLEndpoints, headers:[[String: String]], requestData: Value?) {
        self.baseUrl = baseUrl
        self.headers = headers
        self.requestData = requestData
        self.endpoints = endpoints
    }
    
    private func actionUrl() -> String {
        return self.baseUrl + self.endpoints.action
    }
    
    func sendMessage(message: RTVIMessageOutbound) throws {
        Task {
            let actionUrl = self.actionUrl()
            guard let url = URL(string: actionUrl) else {
                throw InvalidAuthBundleError()
            }
            
            Logger.shared.info("ActionUrl: \(actionUrl)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("keep-alive", forHTTPHeaderField: "Connection")
            
            // Adding the custom headers if they have been provided
            for header in self.headers {
                for (key, value) in header {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            
            do {
                if let customBodyParams = self.requestData {
                    var customBundle:Value = try await customBodyParams.convertToRtviValue()
                    try customBundle.addProperty(key: "actions", value: Value.array([try await message.convertToRtviValue()]))
                    request.httpBody = try JSONEncoder().encode( customBundle )
                } else {
                    let textRequest = TextRequest.init(action: message)
                    let messageToSend = try JSONEncoder().encode(textRequest);
                    request.httpBody = messageToSend;
                }
                
                Logger.shared.info("Will request action: \(String(data: request.httpBody!, encoding: .utf8) ?? "")")
                
                let streamDelegate = StreamDelegate(messageId: message.id)
                streamDelegate.onMessage = self.onMessage
                let session = URLSession(configuration: .default, delegate: streamDelegate, delegateQueue: nil)
                let task = session.dataTask(with: request)
                task.resume()
            } catch {
                throw HttpError(underlyingError: error)
            }
        }
    }
    
    // Stream handling using URLSessionDelegate
    class StreamDelegate: NSObject, URLSessionDataDelegate {
        
        // callback for the messages that we are going to receive from the HTTP
        public var onMessage: ((RTVIMessageInbound) -> Void)? = nil
        
        private var buffer: String = ""
        private var isEventStream: Bool = false
        
        private var messageId: String?
        
        init(messageId: String) {
            super.init()
            self.messageId = messageId
        }
        
        private func base64Decode(_ encodedData: String) -> String? {
            guard let data = Data(base64Encoded: encodedData) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        
        private func parseStreamData() throws {
            while let boundaryRange = self.buffer.range(of: "\n\n") {
                let message = String(self.buffer[..<boundaryRange.lowerBound])
                self.buffer = String(self.buffer[boundaryRange.upperBound...]) // Update the buffer to remove the processed message
                
                let lines = message.split(separator: "\n")
                var encodedData = ""
                for line in lines {
                    if let colonIndex = line.firstIndex(of: ":") {
                        encodedData += line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
                    }
                }
                
                if let jsonData = base64Decode(encodedData), let data = jsonData.data(using: .utf8) {
                    do {
                        Logger.shared.debug("Received jsonData: \(jsonData) ")
                        let appMessage = try JSONDecoder().decode(RTVIMessageInbound.self, from: data)
                        self.onMessage?(appMessage)
                    } catch {
                        Logger.shared.error("Failed to parse JSON: \(error)")
                        throw error
                    }
                }
            }
        }
        
        // This function is called when headers are received (where we check the Content-Type)
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    Logger.shared.error("Failed with status code: \(httpResponse.statusCode)")
                    do {
                        let errorData = try? String(data: JSONEncoder()
                            .encode(
                                ErrorResponse(error: "Request failed with status code \(httpResponse.statusCode)")
                            ), encoding: .utf8)
                        let errorMessage = RTVIMessageInbound(
                            type: RTVIMessageInbound.MessageType.ERROR_RESPONSE,
                            data: errorData,
                            id: self.messageId
                        )
                        self.onMessage?(errorMessage)
                    } catch {
                    }
                    completionHandler(.cancel)
                    return
                }
                
                // Check Content-Type for event-stream
                if let contentType = httpResponse.allHeaderFields["Content-Type"] as? String, contentType.contains("text/event-stream") {
                    self.isEventStream = true
                } else {
                    self.isEventStream = false
                }
                Logger.shared.debug("isEventStream \(isEventStream)")
                
                // Continue processing the data
                completionHandler(.allow)
            }
        }
        
        // This function is called whenever new data arrives
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            if isEventStream {
                // Handle event stream
                if let chunk = String(data: data, encoding: .utf8) {
                    self.buffer += chunk
                    do {
                        try parseStreamData()
                    } catch {
                        Logger.shared.error("Error parsing stream data: \(error)")
                    }
                }
            } else {
                // Handle non-streamed data (regular JSON response)
                do {
                    let appMessage = try JSONDecoder().decode(RTVIMessageInbound.self, from: data)
                    self.onMessage?(appMessage)
                } catch {
                    Logger.shared.error("Failed to parse regular JSON: \(error)")
                }
            }
        }
        
        // Handle task completion
        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                Logger.shared.error("Stream task completed with error: \(error)")
            } else {
                Logger.shared.debug("Stream task completed successfully.")
            }
        }
    }
    
}
