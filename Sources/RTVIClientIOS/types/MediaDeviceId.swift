import Foundation

/// A unique identifier for a media device.
public struct MediaDeviceId: Equatable {
    public let id: String
    
    public init(id: String) {
        self.id = id
    }
}
