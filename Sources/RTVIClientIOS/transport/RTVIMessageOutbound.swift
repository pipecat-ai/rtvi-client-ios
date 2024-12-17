import Foundation

/// An RTVI control message sent to the Transport.
public struct RTVIMessageOutbound: Encodable {

    public let id: String
    public let label: String
    public let type: String
    public let data: Value?

    /// Messages from the client to the server.
    public enum MessageType {
        public static let UPDATE_CONFIG = "update-config"
        public static let GET_CONFIG = "get-config"
        public static let DESCRIBE_CONFIG = "describe-config"
        public static let ACTION = "action"
        public static let DESCRIBE_ACTIONS = "describe-actions"
        public static let CLIENT_READY = "client-ready"
    }

    public init(id: String = String (UUID().uuidString.prefix(8)), label: String = "rtvi-ai", type: String, data: Value? = nil) {
        self.id = id
        self.label = label
        self.type = type
        self.data = data
    }

    static func action(actionData: ActionRequest) async throws -> RTVIMessageOutbound {
        return RTVIMessageOutbound(
            type: RTVIMessageOutbound.MessageType.ACTION,
            data: try await actionData.convertToRtviValue()
        )
    }

    static func updateConfig(config: [ServiceConfig], interrupt: Bool) async throws -> RTVIMessageOutbound {
        let configAsValue = try await config.convertToRtviValue()
        let data = Value.object(["config": configAsValue, "interrupt": Value.boolean(interrupt)])
        return RTVIMessageOutbound(
            type: RTVIMessageOutbound.MessageType.UPDATE_CONFIG,
            data: data
        )
    }

    static func describeConfig() -> RTVIMessageOutbound {
        return RTVIMessageOutbound(
            type: RTVIMessageOutbound.MessageType.DESCRIBE_CONFIG
        )
    }

    static func getConfig() -> RTVIMessageOutbound {
        return RTVIMessageOutbound(
            type: RTVIMessageOutbound.MessageType.GET_CONFIG
        )
    }

    static func describeActions() -> RTVIMessageOutbound {
        return RTVIMessageOutbound(
            type: RTVIMessageOutbound.MessageType.DESCRIBE_ACTIONS
        )
    }

    // Decode action data, if this outbound message represents an action request.
    // This is useful for implementing transports that can intercept and handle action requests in their own way.
    public func decodeActionData() -> ActionRequest? {
        if type == RTVIMessageOutbound.MessageType.ACTION {
            do {
                let encodedData = try JSONEncoder().encode(data)
                return try JSONDecoder().decode(ActionRequest.self, from: encodedData)
            } catch {}
        }
        return nil
    }
}



