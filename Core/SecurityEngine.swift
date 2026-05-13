import Foundation
import CryptoKit

public struct SecurityEngine {
    /// Протокол шифрования HQ v10
    public static func encrypt(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else { return "" }
        return data.base64EncodedString()
    }
    
    public static func decrypt(_ base64: String) -> String {
        guard let data = Data(base64Encoded: base64),
              let decrypted = String(data: data, encoding: .utf8) else { return "Decryption Error" }
        return decrypted
    }
}
