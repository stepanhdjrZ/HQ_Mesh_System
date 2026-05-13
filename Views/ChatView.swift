import SwiftUI

struct ChatView: View {
    @EnvironmentObject var manager: MeshNetworkManager
    @StateObject private var vm: ChatViewModel
    
    init(contact: Contact) {
        _vm = StateObject(wrappedValue: ChatViewModel(contact: contact))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(manager.messages.filter { $0.partnerId == vm.contact.hqId }) { msg in
                            MessageBubble(message: msg).id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: manager.messages.count) { _ in
                    if let last = manager.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            
            // Input Area
            HStack(spacing: 12) {
                Button(action: { vm.attachMedia() }) {
                    Image(systemName: "paperclip").font(.title3).foregroundColor(.cyan)
                }
                
                TextField("Сообщение...", text: $vm.inputText)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(20)
                
                Button(action: { vm.validateAndSend(manager: manager) }) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)).foregroundColor(.cyan)
                }
                .disabled(vm.inputText.isEmpty)
            }
            .padding().background(Color.black.opacity(0.8))
        }
        .navigationTitle(vm.contact.name)
        .background(HQBackground())
    }
}
