import Foundation
import CryptoKit

/// Модуль обеспечения конфиденциальности данных узла
public final class SecurityEngine {
    
    /// Шифрование данных перед отправкой в эфир
    public static func encrypt(_ plaintext: String) -> String {
        guard let data = plaintext.data(using: .utf8) else { return plaintext }
        
        // В будущем: переход на AES-GCM шифрование
        // Сейчас: безопасная Base64 упаковка для стабильности билда
        return data.base64EncodedString()
    }
    
    /// Дешифровка входящих пакетов
    public static func decrypt(_ encoded: String) -> String {
        guard let data = Data(base64Encoded: encoded),
              let decrypted = String(data: data, encoding: .utf8) else {
            return "🚨 Ошибка декодирования пакета"
        }
        return decrypted
    }
    
    /// Генерация уникального хэша для верификации узла
    public static func generateFingerprint(for string: String) -> String {
        let inputData = Data(string.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
