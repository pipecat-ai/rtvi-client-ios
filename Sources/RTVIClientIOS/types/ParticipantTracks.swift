import Foundation

/// Media tracks associated with a participant.
public struct ParticipantTracks: Equatable {
    public let audio: MediaTrackId?
    public let video: MediaTrackId?
    
    public init(audio: MediaTrackId?, video: MediaTrackId?) {
        self.audio = audio
        self.video = video
    }
}
