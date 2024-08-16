import Foundation

/// Helper class for sending messages to the server and awaiting the response.
class MessageDispatcher {
    
    private var transport: Transport
    /// How long to wait before resolving the message/
    private var gcTime: TimeInterval
    @MainActor
    private var queue: [QueuedVoiceMessage] = []
    private var gcTimer: Timer?

    init(transport: Transport) {
        self.gcTime = 10.0 // 10 seconds
        self.transport = transport
        startGCTimer()
    }

    deinit {
        stopGCTimer()
    }

    @MainActor 
    func dispatch(message: VoiceMessageOutbound) throws-> Promise<VoiceMessageInbound> {
        let promise = Promise<VoiceMessageInbound>()
        self.queue.append(QueuedVoiceMessage(
            message: message,
            timestamp: Date(),
            promise: promise
        ))
        do {
            try self.transport.sendMessage(message: message)
        } catch {
            Logger.shared.error("Failed to send app message \(error)")
            if let index = queue.firstIndex(where: { $0.message.id == message.id }) {
                // Removing the item that we have failed to send
                self.queue.remove(at: index)
            }
            throw error
        }
        return promise
    }
    
    @MainActor
    func dispatchAsync(message: VoiceMessageOutbound) async throws -> VoiceMessageInbound {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let promise = try self.dispatch(message: message)
                promise.onResolve = { (inboundMessage: VoiceMessageInbound) in
                    continuation.resume(returning: inboundMessage)
                }
                promise.onReject = { (error: Error) in
                    continuation.resume(throwing: error)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func resolveReject(message: VoiceMessageInbound, resolve: Bool = true) -> VoiceMessageInbound {
        DispatchQueue.main.async {
            if let index = self.queue.firstIndex(where: { $0.message.id == message.id }) {
                let queuedMessage = self.queue[index]
                if resolve {
                    queuedMessage.promise.resolve(value:message)
                } else {
                    if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: Data(message.data!.utf8)) {
                        queuedMessage.promise.reject(error:BotResponseError(message: "Received error response from backend: \(errorResponse.error)"))
                    } else {
                        queuedMessage.promise.reject(error:BotResponseError())
                    }
                }
                self.queue.remove(at: index)
            } else {
                // unknown messages are just ignored
            }
        }
        return message
            
    }

    func resolve(message: VoiceMessageInbound) -> VoiceMessageInbound {
        return resolveReject(message: message, resolve: true)
    }

    func reject(message: VoiceMessageInbound) -> VoiceMessageInbound {
        return resolveReject(message: message, resolve: false)
    }
    
    /// Removing the messages that we have not received a response in the specified time
    private func gc() {
        let currentTime = Date()
        DispatchQueue.main.async {
            self.queue.removeAll { queuedMessage in
                let timeElapsed = currentTime.timeIntervalSince(queuedMessage.timestamp)
                if timeElapsed >= self.gcTime {
                    queuedMessage.promise.reject(error:ResponseTimeoutError())
                    return true
                }
                return false
            }
        }
    }

    private func startGCTimer() {
        gcTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.gc()
        }
    }

    private func stopGCTimer() {
        gcTimer?.invalidate()
        gcTimer = nil
    }
}

struct QueuedVoiceMessage {
    let message: VoiceMessageOutbound
    let timestamp: Date
    let promise: Promise<VoiceMessageInbound>
}
