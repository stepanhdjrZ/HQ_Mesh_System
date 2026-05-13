import Foundation
import SwiftUI
import Combine

final class ChatViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var isEmojiPickerPresented: Bool = false
    
    let contact: Contact
    private var cancellables = Set<AnyCancellable>()
    
    init(contact: Contact) {
        self.contact = contact
    }
    
    func validateAndSend(manager: MeshNetworkManager) {
        let cleanText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        
        // Масштабируемая отправка через менеджер
        manager.broadcastData(to: contact.hqId, content: cleanText)
        
        // Очистка и тактильный отклик
        self.inputText = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // В будущем здесь будет логика отправки фото/файлов
    func attachMedia() {
        print("[CHAT] Прикрепление медиафайлов...")
    }
}
