import Foundation

public protocol LLMHelperDelegate {
    func onLLMJsonCompletion(jsonString: String)
    /// Invoked when the LLM attempts to invoke a function. The provided callback must be provided with a return value.
    func onLLMFunctionCall(functionCallData: LLMFunctionCallData, onResult: ((Value) async -> Void)) async
    func onLLMFunctionCallStart(functionName: String)
}

public extension LLMHelperDelegate {
    func onLLMJsonCompletion(jsonString: String) {}
    func onLLMFunctionCall(functionCallData: LLMFunctionCallData, onResult: ((Value) async -> Void)) async {}
    func onLLMFunctionCallStart(functionName: String) {}
}

private struct LLMMessageType {
    struct Incoming {
        static let LLMFunctionCall = "llm-function-call"
        static let LLMFunctionCallStart = "llm-function-call-start"
        static let LLMJsonCompletion = "llm-json-completion"
    }
    
    struct Outgoing {
        static let LLMFunctionCallResult = "llm-function-call-result"
    }
}

public struct LLMFunctionCallData: Codable {
    public let functionName: String
    public let toolCallID: String
    public let args: Value
    
    enum CodingKeys: String, CodingKey {
        case functionName = "function_name"
        case toolCallID = "tool_call_id"
        case args
    }
}

public struct LLMFunctionCallResult: Codable {
    let functionName: String
    let toolCallID: String
    let arguments: Value
    let result: Value
    
    enum CodingKeys: String, CodingKey {
        case functionName = "function_name"
        case toolCallID = "tool_call_id"
        case arguments
        case result
    }
}

public struct LLMContextMessage: Codable {
    public let role: String
    public let content: String
    
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct LLMContext: Codable {
    public let messages: [LLMContextMessage]?
    
    public init(messages: [LLMContextMessage]?) {
        self.messages = messages
    }
}

struct FunctionCallParams {
    let functionName: String
    let arguments: Value
}

typealias FunctionCallCallback = (FunctionCallParams) -> Promise<Value>

/// Helper for interacting with an LLM service.
public class LLMHelper: RTVIClientHelper {
    
    var voiceClient: RTVIClient
    var service: String
    public var delegate: LLMHelperDelegate?
    
    required public init(service: String, voiceClient: RTVIClient) {
        self.voiceClient = voiceClient
        self.service = service
    }
    
    public func getMessageTypes() -> Set<String> {
        return [
            LLMMessageType.Incoming.LLMFunctionCall,
            LLMMessageType.Incoming.LLMFunctionCallStart,
            LLMMessageType.Incoming.LLMJsonCompletion
        ]
    }
    
    private func isVoiceClientReady() -> Bool {
        return self.voiceClient.state == .ready
    }
    
    private func _getMessagesKey() -> String {
        return self.isVoiceClientReady() ? "messages" : "initial_messages"
    }
    
    // --- Actions
    
    /// Returns the bot's current LLM context. Bot must be in the ready state.
    public func getContext() async throws -> LLMContext? {
        try await self.voiceClient.action(action: ActionRequest.init(
            service: self.service,
            action: "get_context"
        ), resultType: LLMContext.self)
    }
    
    /// Returns the bot's current LLM context. Bot must be in the ready state.
    public func getContext(completion: ((Result<LLMContext?, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                let llmContext = try await self.getContext()
                completion?(.success((llmContext)))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "getContext", underlyingError: error)))
            }
        }
    }
    
    /// Update the bot's LLM context.
    public func setContext(context: LLMContext, interrupt: Bool = false) async throws {
        try await self.voiceClient.action(action: ActionRequest.init(
            service: self.service,
            action: "set_context",
            arguments: [
                Argument(
                    name: self._getMessagesKey(),
                    value: (context.messages ?? []).convertToRtviValue()
                ),
                Argument(
                    name: "interrupt",
                    value: interrupt.convertToRtviValue()
                )
            ]
        ))
    }
    
    /// Update the bot's LLM context.
    public func setContext(context: LLMContext, interrupt: Bool = false, completion: ((Result<Void, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                try await self.setContext(context: context, interrupt:interrupt)
                completion?(.success(()))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "setContext", underlyingError: error)))
            }
        }
    }
    
    /// Append a new message to the LLM context.
    public func appendToMessages(message: LLMContextMessage, runImmediately: Bool = false) async throws {
        try await self.voiceClient.action(action: ActionRequest.init(
            service: self.service,
            action: "append_to_messages",
            arguments: [
                Argument(
                    name: "messages",
                    value: [message].convertToRtviValue()
                ),
                Argument(
                    name: "run_immediately",
                    value: runImmediately.convertToRtviValue()
                )
            ]
        ))
    }
    
    /// Append a new message to the LLM context.
    public func appendToMessages(message: LLMContextMessage, runImmediately: Bool = false, completion: ((Result<Void, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                try await self.appendToMessages(message: message, runImmediately:runImmediately)
                completion?(.success(()))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "appendToMessages", underlyingError: error)))
            }
        }
    }
    
    /// Run the bot's current LLM context.
    /// Useful when appending messages to the context without runImmediately set to true.
    public func run(interrupt: Bool = false) async throws {
        try await self.voiceClient.action(action: ActionRequest.init(
            service: self.service,
            action: "run",
            arguments: [
                Argument(
                    name: "interrupt",
                    value: interrupt.convertToRtviValue()
                )
            ]
        ))
    }
    
    /// Run the bot's current LLM context.
    /// Useful when appending messages to the context without runImmediately set to true.
    public func run(interrupt: Bool = false, completion: ((Result<Void, AsyncExecutionError>) -> Void)?) {
        Task {
            do {
                try await self.run(interrupt: interrupt)
                completion?(.success(()))
            } catch {
                completion?(.failure(AsyncExecutionError(functionName: "run", underlyingError: error)))
            }
        }
    }
    
    public func handleMessage(msg: RTVIMessageInbound) {
        guard let type = msg.type else {
            // Ignoring the message, it doesn't have a type
            return
        }
        Logger.shared.debug("LLMHelper, received voice message \(msg)")
        switch type {
        case LLMMessageType.Incoming.LLMJsonCompletion:
            if let jsonData = msg.data {
                self.delegate?.onLLMJsonCompletion(jsonString: jsonData)
            }
        case LLMMessageType.Incoming.LLMFunctionCallStart:
            if let functionCallData = try? JSONDecoder().decode(LLMFunctionCallData.self, from: Data(msg.data!.utf8)) {
                self.delegate?.onLLMFunctionCallStart(functionName: functionCallData.functionName)
            }
        case LLMMessageType.Incoming.LLMFunctionCall:
            if let functionCallData = try? JSONDecoder().decode(LLMFunctionCallData.self, from: Data(msg.data!.utf8)) {
                Task {
                    await self.delegate?.onLLMFunctionCall(functionCallData: functionCallData) { result in
                        let resultData = try? await LLMFunctionCallResult(
                            functionName: functionCallData.functionName,
                            toolCallID: functionCallData.toolCallID,
                            arguments: functionCallData.args,
                            result: result
                        ).convertToRtviValue()
                        let resultMessage = RTVIMessageOutbound(
                            type: LLMMessageType.Outgoing.LLMFunctionCallResult,
                            data: resultData
                        )
                        voiceClient.sendMessage(msg: resultMessage){ result in
                            if case .failure(let error) = result {
                                Logger.shared.error("Failing to send app result message \(error)")
                            }
                        }
                    }
                }
            }
        default:
            // Ignoring any other message
            return
        }
    }
    
}

