import SwiftUI

// Добавляем в GlobalCore:
class GlobalCore: ... {
    @Published var showUpdateAlert = false
    @Published var serverVersion = ""
    let currentAppVersion = "5.2" // Твоя текущая версия

    func receiveFromServer() {
        webSocketTask?.receive { result in
            // ... (предыдущий код)
            if let packet = try? JSONDecoder().decode(VersionPacket.self, from: data) {
                if packet.version != self.currentAppVersion {
                    DispatchQueue.main.async {
                        self.serverVersion = packet.version
                        self.showUpdateAlert = true
                    }
                }
            }
        }
    }
    
    func triggerUpdate() {
        // Ссылка, которая заставляет iOS начать установку
        // ЗАМЕНИ НА СВОЙ АДРЕС NGROK
        let urlString = "itms-services://?action=download-manifest&url=https://ТВОЙ_NGROK_АДРЕС/manifest.plist"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// В интерфейс добавляем Alert:
.alert("Доступно обновление v\(core.serverVersion)", isPresented: $core.showUpdateAlert) {
    Button("Обновить") { core.triggerUpdate() }
    Button("Позже", role: .cancel) {}
} message: {
    Text("Новая версия уже на твоем Ryzen. Обновимся?")
}
