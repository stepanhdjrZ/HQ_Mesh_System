import SwiftUI
import UIKit // Обязательно для UIBezierPath

// 1. ФИКС УГЛОВ: Позволяет закруглять конкретные углы (как в Telegram)
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// 2. ФИКС МЕНЕДЖЕРА: Заглушка метода отправки, чтобы ChatViewModel не падал
extension MeshNetworkManager {
    func broadcastData(to target: String, content: String) {
        // Здесь потом будет логика отправки пакетов через Bluetooth/LocalNetwork
        print("⚡️ [MESH] Broadcasting to \(target): \(content)")
    }
}
