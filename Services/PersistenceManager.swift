import Foundation

/// Менеджер персистентности (постоянного хранения данных)
final class PersistenceManager {
    private let defaults = UserDefaults.standard
    
    enum Keys: String {
        case nodeID = "hq_node_id"
        case nickname = "hq_nick"
        case accessGranted = "hq_access_granted"
        case messageQueue = "hq_msg_queue"
    }
    
    func save<T>(_ value: T, forKey key: Keys) {
        defaults.set(value, forKey: key.rawValue)
        LoggerService.log("Данные сохранены по ключу: \(key.rawValue)")
    }
    
    func fetchString(forKey key: Keys) -> String? {
        return defaults.string(forKey: key.rawValue)
    }
    
    func fetchBool(forKey key: Keys) -> Bool {
        return defaults.bool(forKey: key.rawValue)
    }
    
    func wipeAllData() {
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
        LoggerService.log("ВНИМАНИЕ: Все локальные данные узла уничтожены!", level: .security)
    }
}
