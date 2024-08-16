import Foundation

/// Information about a session participant.
public struct Participant {
    public let id: ParticipantId
    public let name: String?
    /// True if this participant represents the local user, false otherwise.
    public let local: Bool
    
    public init(id: ParticipantId, name: String?, local: Bool) {
        self.id = id
        self.name = name
        self.local = local
    }
}
