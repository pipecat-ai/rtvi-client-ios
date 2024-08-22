import Foundation

/// An identifier for a media track.
public struct MediaTrackId: Hashable, Equatable {
    let id: String
    
    public init(id: String) {
        self.id = id
    }
}
