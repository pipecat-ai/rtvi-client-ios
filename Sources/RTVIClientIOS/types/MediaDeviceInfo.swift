import Foundation

/// Information about a media device.
public struct MediaDeviceInfo: Equatable {
    
    public let id: MediaDeviceId
    public let name: String
    
    public init(id: MediaDeviceId, name: String) {
        self.id = id
        self.name = name
    }
    
    public static func == (lhs: MediaDeviceInfo, rhs: MediaDeviceInfo) -> Bool {
        lhs.id == rhs.id
    }
}
