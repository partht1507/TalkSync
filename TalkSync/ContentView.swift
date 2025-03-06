import SwiftUI
import NaturalLanguage
import Combine

struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var networkManager = NetworkManager()
    
    @State private var conversation: [Message] = []
    @State private var isRecording = false
    @State private var userInput: String = ""
    @State private var detectedLanguage: String = ""
    
    // For controlling the side menu visibility.
    @State private var showSideMenu: Bool = false
    
    // Combine cancellable for debouncing.
    @State private var debounceCancellable: AnyCancellable?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main Content
                VStack {
                    // Chat list that scrolls to the latest message.
                    ScrollViewReader { proxy in
                        List {
                            ForEach(conversation) { message in
                                ChatMessageRow(message: message)
                                    .id(message.id)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .onChange(of: conversation) { oldValue, newValue in
                            if let last = newValue.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Display detected language and recognized speech text.
                    VStack(alignment: .leading, spacing: 4) {
                        if !detectedLanguage.isEmpty {
                            Text("Detected Language: \(detectedLanguage)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        if !speechManager.recognizedText.isEmpty {
                            Text("Recognized: \(speechManager.recognizedText)")
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // Keyboard input field with send button.
                    HStack {
                        TextField("Enter message", text: $userInput, onCommit: sendTextMessage)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(minHeight: 30)
                        
                        Button(action: sendTextMessage) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 24))
                        }
                    }
                    .padding([.leading, .trailing, .bottom])
                    
                    // Microphone button.
                    Button(action: toggleRecording) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                    }
                    .padding(.bottom)
                }
                .navigationTitle("TalkSync")
                .toolbar {
                    // Hamburger button on left to toggle side menu.
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            withAnimation {
                                showSideMenu.toggle()
                            }
                        }) {
                            Image(systemName: "line.horizontal.3")
                                .imageScale(.large)
                        }
                    }
                    // New Chat button on right.
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: clearChat) {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
                
                // Side Menu Overlay.
                if showSideMenu {
                    SideMenuView(showSideMenu: $showSideMenu)
                        .transition(.move(edge: .leading))
                }
            }
        }
        .onAppear(perform: setupDebounce)
    }
    
    // Set up a debounced publisher to auto-send after 1.5 seconds of silence.
    private func setupDebounce() {
        debounceCancellable = speechManager.$recognizedText
            .debounce(for: .seconds(1.5), scheduler: DispatchQueue.main)
            .sink { debouncedText in
                if isRecording && !debouncedText.isEmpty {
                    speechManager.stopRecording()
                    isRecording = false
                    processMessage(debouncedText, isAudio: true)
                    speechManager.recognizedText = ""
                }
            }
    }
    
    // Clear conversation and reset state.
    private func clearChat() {
        conversation.removeAll()
        userInput = ""
        detectedLanguage = ""
        speechManager.recognizedText = ""
    }
    
    // Toggle between starting and stopping speech recognition.
    private func toggleRecording() {
        if isRecording {
            speechManager.stopRecording()
            isRecording = false
            let finalText = speechManager.recognizedText
            processMessage(finalText, isAudio: true)
            // Delay clearing so the user can see the recognized text briefly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.speechManager.recognizedText = ""
            }
        } else {
            speechManager.startRecording()
            isRecording = true
        }
    }
    
    // Called when the user sends a message via keyboard.
    private func sendTextMessage() {
        let trimmed = userInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let messageToSend = trimmed
        // Clear the text field asynchronously.
        DispatchQueue.main.async {
            self.userInput = ""
        }
        processMessage(messageToSend, isAudio: false)
    }
    
    // Process the message: detect language, always translate to English, then send.
    private func processMessage(_ text: String, isAudio: Bool = false) {
        let language = detectLanguage(for: text)
        detectedLanguage = language
        
        networkManager.translateIfNeeded(text: text) { translatedText in
            addUserMessage(text: translatedText, isAudio: isAudio)
            sendToBackend(message: translatedText, isAudio: isAudio)
        }
    }
    
    // Append a user message to the conversation.
    private func addUserMessage(text: String, isAudio: Bool = false) {
        let message = Message(sender: .user, text: text, isAudio: isAudio)
        conversation.append(message)
    }
    
    // Send the message to the backend and append the bot's reply.
    // If the message was sent as audio, the reply is spoken automatically.
    private func sendToBackend(message: String, isAudio: Bool = false) {
        networkManager.sendMessage(message) { reply in
            let botMessage = Message(sender: .bot, text: reply, isAudio: false)
            conversation.append(botMessage)
            if isAudio {
                // Speak the received (bot) message when the sent message was audio.
                TTSManager.shared.speak(message: reply, messageId: botMessage.id)
            }
        }
    }
    
    // Detect the language using NLLanguageRecognizer.
    private func detectLanguage(for text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? "und"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
