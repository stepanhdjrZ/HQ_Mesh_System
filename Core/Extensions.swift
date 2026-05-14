import SwiftUI
import UIKit 

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

// 2. ФИКС МЕНЕДЖЕРА: Добавляем методы и массивы, чтобы UI не падал
extension MeshNetworkManager {
    // Заглушка отправки сообщений
    func broadcastData(to target: String, content: String) {
        print("⚡️ [MESH] Broadcasting to \(target): \(content)")
    }
    
    // 🎯 ВОТ ОНО! Даем Менеджеру массив узлов, чтобы Радар мог их посчитать
    var nearbyNodes: [String] {
        return ["Node Alpha", "Node Beta", "Node Gamma"] 
    }
}
