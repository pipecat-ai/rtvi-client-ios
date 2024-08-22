import Foundation

/// Media tracks for the local user and remote bot.
public struct Tracks: Equatable {
    let local: ParticipantTracks
    let bot: ParticipantTracks?
    
    public init(local: ParticipantTracks, bot: ParticipantTracks?) {
        self.local = local
        self.bot = bot
    }
}
