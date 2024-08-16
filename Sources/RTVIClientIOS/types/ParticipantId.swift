import Foundation

/// A unique identifier for a session participant.
public struct ParticipantId: Equatable {
    let id: String
    
    public init(id: String) {
        self.id = id
    }
}
