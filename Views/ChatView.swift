import SwiftUI

struct ChatView: View {
    @State var contactID: String
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var text = ""
    
    var body: some View {
        VStack {
            ScrollView {
                let filteredMessages = meshManager.messages.filter { $0.partnerId == contactID }
                VStack(spacing: 12) {
                    ForEach(filteredMessages) { msg in
                        MessageBubble(msg: msg)
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            
            // Панель ввода
            HStack {
                TextField("Зашифрованное сообщение...", text: $text)
                    .padding(10).background(Color(UIColor.systemBackground)).cornerRadius(20)
                
                if !text.isEmpty {
                    Button(action: {
                        meshManager.sendMessage(to: contactID, text: text)
                        text = ""
                    }) {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 30)).foregroundColor(.blue)
                    }
                }
            }
            .padding().background(Color(UIColor.secondarySystemBackground))
        }
        .navigationTitle(contactID)
    }
}

struct MessageBubble: View {
    let msg: ChatMessage
    
    var body: some View {
        HStack {
            if msg.isMe { Spacer() }
            
            Text(msg.text)
                .padding(12)
                .background(msg.isMe ? Color.blue : Color.white)
                .foregroundColor(msg.isMe ? .white : .black)
                .cornerRadius(18)
            
            if !msg.isMe { Spacer() }
        }
    }
}
