import Foundation

/// The current state of the session transport.
public enum TransportState {
    case idle
    case initializing
    case initialized
    case handshaking
    case connecting
    case connected
    case ready
    case disconnecting
    case disconnected
    case error
}

extension TransportState {
    public var description: String {
        switch self {
        case .idle:
            return "Idle"
        case .initializing:
            return "Initializing"
        case .initialized:
            return "Initialized"
        case .handshaking:
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
