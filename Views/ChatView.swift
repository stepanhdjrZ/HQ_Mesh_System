import SwiftUI

struct ChatView: View {
    @State var contactID: String
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var text = ""
    @State private var showStickers = false
    let hqStickers = ["🚀", "🛰️", "🔥", "👑", "💻", "🛡️", "⚡️", "😎"]
    
    var body: some View {
        VStack(spacing: 0) {
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
            
            if showStickers {
                ScrollView(.horizontal) {
                    HStack(spacing: 20) {
                        ForEach(hqStickers, id: \.self) { s in
                            Button(s) {
                                meshManager.sendMessage(to: contactID, text: s)
                                showStickers = false
                            }.font(.system(size: 45))
                        }
                    }.padding()
                }.background(Color(UIColor.secondarySystemBackground)).frame(height: 80)
            }
            
            HStack {
                Button(action: { showStickers.toggle() }) {
                    Image(systemName: "face.smiling").font(.title2).foregroundColor(.gray)
                }
                TextField("Сообщение...", text: $text)
                    .padding(10).background(Color(UIColor.systemBackground)).cornerRadius(20)
                if !text.isEmpty {
                    Button(action: { meshManager.sendMessage(to: contactID, text: text); text = "" }) {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 30)).foregroundColor(.blue)
                    }
                }
            }.padding().background(Color(UIColor.secondarySystemBackground))
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
                .padding(10)
                .background(msg.isMe ? Color.blue : Color.white)
                .foregroundColor(msg.isMe ? .white : .black)
                .cornerRadius(15)
            if !msg.isMe { Spacer() }
        }
    }
}
