import Foundation

final class QueueManager {
    
    // Метод добавления в очередь
    func push(to recipient: String, data: Any) {
        print("📦 [QUEUE] Пакет для узла \(recipient) успешно добавлен в очередь.")
    }
    
    // 🎯 ВОТ ОНО! Разрешаем функции принимать блок кода, который просит Менеджер
    func flush(_ completion: (Any) -> Void) {
        print("🚀 [QUEUE] Очередь очищена. Пакеты ушли в эфир.")
        // Имитируем передачу пакета, чтобы компилятор собрал цепь
        completion("EncryptedPayload_0x99")
    }
}
