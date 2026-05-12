import SwiftUI

struct ChatView: View {
    @State var contactID: String
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var text = ""
    
    var body: some View {
        VStack {
            // Если ID еще не введен, даем поле ввода
            if contactID == "Введите ID контакта" {
                VStack(spacing: 20) {
                    Text("С кем хотим связаться?")
                        .font(.headline)
                    TextField("Например: HQ-1234", text: $contactID)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                }
                .padding()
                Spacer()
            } else {
                // Сам чат
                ScrollView {
                    // Фильтруем сообщения только для этого контакта
                    let filteredMessages = meshManager.messages.filter { $0.partnerId == contactID }
                    
                    ForEach(filteredMessages) { msg in
                        HStack {
                            if msg.isMe { Spacer() }
                            
                            Text(msg.text)
                                .padding(12)
                                .background(msg.isMe ? Color.blue : Color(UIColor.systemGray5))
                                .foregroundColor(msg.isMe ? .white : .primary)
                                .cornerRadius(18)
                            
                            if !msg.isMe { Spacer() }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }
                }
                
                // Панель ввода
                HStack {
                    TextField("Сообщение...", text: $text)
                        .padding(10)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(20)
                    
                    Button(action: {
                        if !text.isEmpty {
                            meshManager.sendMessage(to: contactID, text: text)
                            text = ""
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(contactID == "Введите ID контакта" ? "Новый чат" : contactID)
        .navigationBarTitleDisplayMode(.inline)
    }
}
