import Foundation

// Профессиональная структура пакета для очереди
struct QueuedMessage: Identifiable {
    let id: UUID
    let targetID: String
    let payload: Data // Используем Data вместо словаря для стабильности
    var retryCount: Int
    
    init(targetID: String, dictionary: [String: Any]) {
        self.id = UUID()
        self.targetID = targetID
        self.retryCount = 0
        // Конвертируем словарь в сырые данные
        self.payload = (try? JSONSerialization.data(withJSONObject: dictionary)) ?? Data()
    }
    
    var dictionary: [String: Any]? {
        return (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any]
    }
}

final class QueueManager: ObservableObject {
    @Published var pendingQueue: [QueuedMessage] = []
    
    func addToQueue(target: String, data: [String: Any]) {
        let msg = QueuedMessage(targetID: target, dictionary: data)
        DispatchQueue.main.async {
            self.pendingQueue.append(msg)
            LoggerService.log("Пакет для \(target) поставлен в очередь. Всего в очереди: \(self.pendingQueue.count)")
        }
    }
    
    func processQueue(sendAction: ([String: Any]) -> Bool) {
        guard !pendingQueue.isEmpty else { return }
        
        var deliveredIndices = [Int]()
        
        for (index, msg) in pendingQueue.enumerated() {
            if let dict = msg.dictionary, sendAction(dict) {
                deliveredIndices.append(index)
            }
        }
        
        // Очистка очереди
        DispatchQueue.main.async {
            for index in deliveredIndices.reversed() {
                self.pendingQueue.remove(at: index)
            }
            if !deliveredIndices.isEmpty {
                LoggerService.log("Очередь обработана. Доставлено пакетов: \(deliveredIndices.count)")
            }
        }
    }
}
