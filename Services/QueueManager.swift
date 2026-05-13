import Foundation

struct QueuedMessage: Codable, Identifiable {
    let id: UUID
    let targetID: String
    let payload: [String: Any]
    var retryCount: Int
    
    enum CodingKeys: String, CodingKey { case id, targetID, payload, retryCount }
    
    // Кастомный энкодер, так как [String: Any] не кодируется по дефолту
    init(targetID: String, payload: [String: Any]) {
        self.id = UUID()
        self.targetID = targetID
        self.payload = payload
        self.retryCount = 0
    }
}

final class QueueManager: ObservableObject {
    @Published var pendingQueue: [QueuedMessage] = []
    private let persistence = PersistenceManager()
    
    func addToQueue(target: String, data: [String: Any]) {
        let msg = QueuedMessage(targetID: target, payload: data)
        pendingQueue.append(msg)
        LoggerService.log("Пакет для \(target) поставлен в очередь ожидания.")
        saveQueue()
    }
    
    func processQueue(sendAction: (QueuedMessage) -> Bool) {
        guard !pendingQueue.isEmpty else { return }
        
        LoggerService.log("Попытка протолкнуть очередь: \(pendingQueue.count) пакетов.")
        
        var deliveredIndices = [Int]()
        for (index, msg) in pendingQueue.enumerated() {
            if sendAction(msg) {
                deliveredIndices.append(index)
            }
        }
        
        // Удаляем доставленные
        for index in deliveredIndices.reversed() {
            pendingQueue.remove(at: index)
        }
        saveQueue()
    }
    
    private func saveQueue() {
        // Здесь логика сохранения в PersistenceManager, чтобы не терять при перезагрузке
    }
}
