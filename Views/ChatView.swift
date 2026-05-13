import SwiftUI

struct ChatView: View {
    let contact: Contact
    @EnvironmentObject var manager: MeshNetworkManager
    @StateObject private var vm: ChatViewModel
    
    // Инициализатор связывает вью с её "мозгом"
    init(contact: Contact) {
        self.contact = contact
        self._vm = StateObject(wrappedValue: ChatViewModel(contact: contact))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Message Canvas
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(manager.messages.filter { $0.partnerId == contact.hqId }) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                .onChange(of: manager.messages.count) { _ in
                    if let lastId = manager.messages.last?.id {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            
            // MARK: - Input Command Center
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.1))
                
                HStack(alignment: .bottom, spacing: 12) {
                    Button(action: { vm.attachMedia() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.cyan)
                            .padding(8)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                    
                    TextField("Передать пакет данных...", text: $vm.inputText)
                        .hqInput()
                        .frame(minHeight: 44)
                    
                    if !vm.inputText.isEmpty {
                        Button(action: { vm.validateAndSend(manager: manager) }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.cyan)
                                .shadow(color: .cyan.opacity(0.3), radius: 5)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(contact.name).font(.headline).foregroundColor(.white)
                    Text("P2P Активен").font(.system(size: 10, weight: .bold)).foregroundColor(.green)
                }
            }
        }
        .background(HQBackground())
    }
}
