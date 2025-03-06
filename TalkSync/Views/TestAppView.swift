import SwiftUI
import NaturalLanguage
import Combine
import Foundation  // Ensure Foundation is imported for .seconds


struct TestAppView: View {
    // For typed input and response display.
    @State private var inputText: String = ""
    @State private var responseText: String = ""
    @State private var isDarkMode: Bool = false

    // Speech-to-text properties.
    @StateObject private var speechManager = SpeechManager()
    @State private var isRecording: Bool = false
    @State private var debounceCancellable: AnyCancellable?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color adapts to mode.
                Color(isDarkMode ? .black : .white)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // Display recognized speech text (if any).
                    if !speechManager.recognizedText.isEmpty {
                        Text("Recognized: \(speechManager.recognizedText)")
                            .foregroundColor(isDarkMode ? .white : .black)
                            .padding()
                    }
                    
                    // Input field for typed input.
                    TextField("Enter input (e.g. 3+5, 65-60, or a message)", text: $inputText)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
                        .padding(.horizontal, 50)
                    
                    // Send button for typed input.
                    Button(action: {
                        sendRequest(for: inputText)
                        inputText = ""
                    }) {
                        Text("Send")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue))
                            .foregroundColor(.white)
                            .padding(.horizontal, 50)
                    }
                    .padding(.top, 10)
                    
                    // Microphone button for speech recognition.
                    Button(action: toggleRecording) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                    }
                    .padding(.top, 10)
                    
                    // Displaying the response.
                    Text("Response:")
                        .font(.headline)
                        .foregroundColor(isDarkMode ? .white : .black)
                        .padding(.top, 20)
                    
                    Text(responseText)
                        .padding()
                        .multilineTextAlignment(.center)
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Spacer()
                }
            }
            .navigationTitle("Test App")
            .toolbar {
                // Dark/Light mode toggle button.
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isDarkMode.toggle()
                    }) {
                        Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                            .font(.title2)
                            .foregroundColor(isDarkMode ? .yellow : .blue)
                    }
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
        .onAppear(perform: setupDebounce)
    }
    
    // Setup a debounced publisher that triggers after 1.5 seconds of silence.
    private func setupDebounce() {
        debounceCancellable = speechManager.$recognizedText
            .debounce(for: .seconds(1.5), scheduler: DispatchQueue.main)
            // Alternative if needed:
            // .debounce(for: DispatchQueue.SchedulerTimeType.Stride(1.5), scheduler: DispatchQueue.main)
            .sink { debouncedText in
                if isRecording && !debouncedText.isEmpty {
                    stopRecordingAndSend()
                }
            }
    }
    
    // Toggle recording: start or stop speech recognition.
    private func toggleRecording() {
        if isRecording {
            stopRecordingAndSend()
        } else {
            speechManager.startRecording()
            isRecording = true
        }
    }
    
    // Stop recording, send the recognized text, and clear it.
    private func stopRecordingAndSend() {
        speechManager.stopRecording()
        isRecording = false
        let recognized = speechManager.recognizedText
        sendRequest(for: recognized)
        // Clear recognized text after a short delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            speechManager.recognizedText = ""
        }
    }
    
    // Send a request to your backend using the provided text.
    private func sendRequest(for text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        var urlString = ""
        // Check for addition expression.
        if trimmedText.contains("+") {
            let addPattern = #"^\s*(-?\d+)\s*\+\s*(-?\d+)\s*$"#
            if let regex = try? NSRegularExpression(pattern: addPattern) {
                let range = NSRange(location: 0, length: trimmedText.utf16.count)
                if let match = regex.firstMatch(in: trimmedText, options: [], range: range),
                   match.numberOfRanges == 3,
                   let range1 = Range(match.range(at: 1), in: trimmedText),
                   let range2 = Range(match.range(at: 2), in: trimmedText) {
                    let firstNumber = String(trimmedText[range1])
                    let secondNumber = String(trimmedText[range2])
                    if let i = Int(firstNumber), let j = Int(secondNumber) {
                        urlString = "http://52.204.226.205:80/SelfHostedService/add?i=\(i)&j=\(j)"
                    } else {
                        self.responseText = "Invalid numbers for addition."
                        return
                    }
                } else {
                    self.responseText = "Invalid format for addition. Use e.g. 3+5."
                    return
                }
            }
        }
        // Check for subtraction expression.
        else if trimmedText.contains("-") {
            let subPattern = #"^\s*(-?\d+)\s*-\s*(-?\d+)\s*$"#
            if let regex = try? NSRegularExpression(pattern: subPattern) {
                let range = NSRange(location: 0, length: trimmedText.utf16.count)
                if let match = regex.firstMatch(in: trimmedText, options: [], range: range),
                   match.numberOfRanges == 3,
                   let range1 = Range(match.range(at: 1), in: trimmedText),
                   let range2 = Range(match.range(at: 2), in: trimmedText) {
                    let firstNumber = String(trimmedText[range1])
                    let secondNumber = String(trimmedText[range2])
                    if let i = Int(firstNumber), let j = Int(secondNumber) {
                        urlString = "http://52.204.226.205:80/SelfHostedService/subtract?i=\(i)&j=\(j)"
                    } else {
                        self.responseText = "Invalid numbers for subtraction."
                        return
                    }
                } else {
                    self.responseText = "Invalid format for subtraction. Use e.g. 65-60."
                    return
                }
            }
        }
        // Otherwise, treat it as a message.
        else {
            if let encodedMessage = trimmedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString = "http://52.204.226.205:80/SelfHostedService/sendmessage?message=\(encodedMessage)"
            }
        }
        
        guard let url = URL(string: urlString) else {
            self.responseText = "Error: Invalid URL."
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.responseText = "Error: \(error.localizedDescription)"
                }
                return
            }
            if let data = data, let result = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.responseText = result
                }
            }
        }
        task.resume()
    }
}

struct TestAppView_Previews: PreviewProvider {
    static var previews: some View {
        TestAppView()
    }
}
