import SwiftUI
import AVFoundation
import Combine

// TTSManager: A singleton class to handle text-to-speech.
class TTSManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = TTSManager()
    private var synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()
    
    // Publishes the ID of the message currently being spoken.
    @Published var currentlySpeakingMessageID: UUID? = nil
    
    private override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    /// Speaks the given message and marks it as currently speaking.
    func speak(message: String, messageId: UUID) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: message)
        // Ensure using an English voice; adjust if needed.
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        currentlySpeakingMessageID = messageId
        synthesizer.speak(utterance)
    }
    
    // Delegate method called when speech finishes.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        currentlySpeakingMessageID = nil
    }
    
    // Delegate method called when speech is cancelled.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        currentlySpeakingMessageID = nil
    }
}

// ChatMessageRow: Displays a chat message and, for bot messages, shows a TTS button.
struct ChatMessageRow: View {
    var message: Message
    @ObservedObject var ttsManager = TTSManager.shared
    
    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer()
                Text(message.text)
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            } else {
                HStack {
                    Text(message.text)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    
                    // TTS button for received messages.
                    Button(action: {
                        ttsManager.speak(message: message.text, messageId: message.id)
                    }) {
                        Image(systemName: "speaker.wave.2.fill")
                            .resizable()
                            .frame(width: 24, height: 24) // Fixed size icon.
                            .foregroundColor(ttsManager.currentlySpeakingMessageID == message.id ? .blue : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
            }
        }
    }
}

struct ChatMessageRow_Previews: PreviewProvider {
    static var previews: some View {
        ChatMessageRow(message: Message(sender: .bot, text: "Hello, how can I help you?", isAudio: false))
    }
}
