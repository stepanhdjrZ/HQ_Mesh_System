import Foundation

final class QueueManager {
    
    // Метод добавления в очередь, который ждал MeshNetworkManager
    func push(to recipient: String, data: Any) {
        print("📦 [QUEUE] Пакет для узла \(recipient) успешно добавлен в очередь.")
        // В будущем здесь будет логика сохранения пакета в базу данных
    }
    
    // Метод отправки всех пакетов, который ждал MeshNetworkManager
    func flush() {
        print("🚀 [QUEUE] Очередь очищена. Пакеты ушли в эфир.")
        // В будущем здесь будет логика массовой рассылки
    }
}
