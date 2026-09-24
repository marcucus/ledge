import Foundation

protocol MediaSource: AnyObject {
    func fetchNowPlayingInfo() async -> MediaState
    func send(_ command: MediaCommand) async
}
