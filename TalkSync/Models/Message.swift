import Foundation

enum Sender {
    case user, bot
}

struct Message: Identifiable, Equatable {
    let id = UUID()
    let sender: Sender
    let text: String
    let isAudio: Bool
}
