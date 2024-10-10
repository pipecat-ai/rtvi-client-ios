import Foundation

/// An RTVI control message sent to the Transport.
public struct RTVIMessageOutbound: Encodable {

    let id: String
    let label: String
    let type: String
    let data: Value?

    /// Messages from the client to the server.
    public enum MessageType {
        static let UPDATE_CONFIG = "update-config"
        static let GET_CONFIG = "get-config"
        static let DESCRIBE_CONFIG = "describe-config"
        static let ACTION = "action"
        static let DESCRIBE_ACTIONS = "describe-actions"
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

}



