import Foundation

class NetworkManager: ObservableObject {
    // Replace with your backend URL
    let openAIBackendURL = URL(string: "https://talksync-backend-684b89663840.herokuapp.com/chat")!
    // Google Translation API endpoint
    let translateURL = URL(string: "https://translation.googleapis.com/language/translate/v2")!
    
    /// Always translates the provided text to English using the Google Cloud Translation API.
    func translateIfNeeded(text: String, completion: @escaping (String) -> Void) {
        // Replace with your actual API key.
        let apiKey = "use_your_google_api_key"
        
        // Build URL with query parameter for API key.
        var components = URLComponents(url: translateURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else {
            completion(text)
            return
        }
        
        let requestBody: [String: Any] = [
            "q": text,
            "target": "en",
            "format": "text"
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody, options: []) else {
            completion(text)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Translation error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(text) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(text) }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let dataDict = json["data"] as? [String: Any],
                   let translations = dataDict["translations"] as? [[String: Any]],
                   let translatedText = translations.first?["translatedText"] as? String {
                    DispatchQueue.main.async {
                        completion(translatedText)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(text)
                    }
                }
            } catch {
                print("JSON parse error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(text) }
            }
        }.resume()
    }
    
    /// Sends the provided English text to the backend.
    func sendMessage(_ text: String, completion: @escaping (String) -> Void) {
        let payload = ["message": text]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            completion("Error creating JSON payload")
            return
        }
        
        var request = URLRequest(url: openAIBackendURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion("Error: \(error.localizedDescription)")
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion("No data from server")
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let reply = json["reply"] as? String {
                    DispatchQueue.main.async {
                        completion(reply)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion("Invalid response from server")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion("JSON parsing error")
                }
            }
        }.resume()
    }
}
