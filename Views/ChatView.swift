import SwiftUI

struct ChatView: View {
    @State var contactID: String
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var text = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                let filteredMessages = meshManager.messages.filter { $0.partnerId == contactID }
                VStack(spacing: 10) {
                    ForEach(filteredMessages) { msg in
                        HStack {
                            if msg.isMe { Spacer() }
                            Text(msg.text)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(msg.isMe ? Color.blue : Color(UIColor.systemBackground))
                                .foregroundColor(msg.isMe ? .white : .primary)
                                .cornerRadius(18)
                                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
                            if !msg.isMe { Spacer() }
                        }
                    }
                }
                .padding()
            }
            .background(Color(UIColor.secondarySystemBackground))
            
            // Панель ввода
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    Image(systemName: "paperclip").font(.title2).foregroundColor(.gray)
                    TextField("Сообщение", text: $text)
                        .padding(10)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(20)
                    if text.isEmpty {
                        Image(systemName: "mic").font(.title2).foregroundColor(.gray)
                    } else {
                        Button(action: {
                            meshManager.sendMessage(to: contactID, text: text)
                            text = ""
                        }) {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)).foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .navigationTitle(contactID)
        .navigationBarTitleDisplayMode(.inline)
    }
}
