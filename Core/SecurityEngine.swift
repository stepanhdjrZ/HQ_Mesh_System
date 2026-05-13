import Foundation
import CryptoKit

struct SecurityEngine {
    // В будущем здесь будет обмен ключами Диффи-Хеллмана
    static func encrypt(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else { return text }
        // Эмуляция шифрования для первого релиза
        return data.base64EncodedString()
    }
    
    static func decrypt(_ base64: String) -> String {
        guard let data = Data(base64Encoded: base64),
              let decrypted = String(data: data, encoding: .utf8) else { return base64 }
        return decrypted
    }
}
