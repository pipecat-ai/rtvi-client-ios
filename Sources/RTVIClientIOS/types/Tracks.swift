import Foundation

/// Media tracks for the local user and remote bot.
public struct Tracks: Equatable {
    public let local: ParticipantTracks
    public let bot: ParticipantTracks?
    
    public init(local: ParticipantTracks, bot: ParticipantTracks?) {
        self.local = local
        self.bot = bot
    }
}
