import SwiftUI

struct ChatListView: View {
    var conversation: [Message]
    
    var body: some View {
        ScrollViewReader { proxy in
            List(conversation) { message in
                ChatMessageRow(message: message)
                    .id(message.id)
            }
            .listStyle(PlainListStyle())
            // Two-parameter onChange: oldValue and newValue
            .onChange(of: conversation) { oldValue, newValue in
                if let last = newValue.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        // Ensure that your Message model includes an initializer that takes isAudio,
        // or provide a default value in the model.
        ChatListView(conversation: [
            Message(sender: .user, text: "Hello!", isAudio: false),
            Message(sender: .bot, text: "Hi there!", isAudio: false)
        ])
    }
}
