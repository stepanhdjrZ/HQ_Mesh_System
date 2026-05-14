import SwiftUI
import UIKit 

// 1. ФИКС УГЛОВ (Для красивого чата)
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

// 2. ФИКС МЕНЕДЖЕРА: Выдаем ему все недостающие списки
extension MeshNetworkManager {
    // Заглушка отправки сообщений
    func broadcastData(to target: String, content: String) {
        print("⚡️ [MESH] Broadcasting to \(target): \(content)")
    }
    
    // Заглушка для Радара 
    var nearbyNodes: [String] {
        return ["Node Alpha", "Node Beta", "Node Gamma"] 
    }
    
    // 🎯 ВОТ ОНО! Возвращаем пустой массив ТВОЕГО реального типа Contact
    var contacts: [Contact] {
        return []
    }
}
