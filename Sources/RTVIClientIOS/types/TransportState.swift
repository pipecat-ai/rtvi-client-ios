import Foundation

/// The current state of the session transport.
public enum TransportState {
    case disconnected
    case initializing
    case initialized
    case authenticating
    case connecting
    case connected
    case ready
    case disconnecting
    case error
}

extension TransportState {
    public var description: String {
        switch self {
        case .initializing:
            return "Initializing"
        case .initialized:
            return "Initialized"
        case .authenticating:
            return "Handshaking"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .ready:
            return "Ready"
        case .disconnecting:
            return "Disconnecting"
        case .disconnected:
            return "Disconnected"
        case .error:
            return "Error"
        }
    }
}
