import Foundation
import SwiftUI

enum AppFlowState {
    case auth
    case main_app
}

final class RegistrationManager: ObservableObject {
    @Published var appState: AppFlowState = .auth
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    @AppStorage("hq_node_id") var myHQID: String = ""
    @AppStorage("hq_username") var username: String = ""
    
    init() {
        if !myHQID.isEmpty {
            self.appState = .main_app
        }
    }
    
    func register(user: String, pass: String) {
        performRequest(path: "/register", body: ["username": user, "password": pass, "node_id": "HQ-\(UUID().uuidString.prefix(8))"])
    }
    
    func login(user: String, pass: String) {
        performRequest(path: "/login", body: ["username": user, "password": pass])
    }
    
    private func performRequest(path: String, body: [String: String]) {
        self.isLoading = true
        self.errorMessage = nil
        
        guard let url = URL(string: AppConstants.apiURL + path) else {
            self.isLoading = false
            self.errorMessage = "Ошибка URL сервера"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 🎯  СЕКРЕТНЫЙ КЛЮЧ: Пробиваем заглушку localtunnel
        request.setValue("true", forHTTPHeaderField: "bypass-tunnel-reminder")
        request.setValue("hq-mesh-client", forHTTPHeaderField: "User-Agent")
        
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Ошибка сети: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "Пустой ответ от сервера"
                    return
                }
                
                if let result = try? JSONDecoder().decode([String: String].self, from: data) {
                    if result["status"] == "success" {
                        self.username = body["username"] ?? ""
                        if let nodeId = result["node_id"] {
                            self.myHQID = nodeId
                        }
                        self.appState = .main_app
                    } else {
                        self.errorMessage = result["detail"] ?? "Ошибка данных"
                    }
                } else {
                    self.errorMessage = "Сервер отклонил запрос. Проверьте туннель."
                }
            }
        }.resume()
    }
    
    func logout() {
        self.myHQID = ""
        self.username = ""
        self.appState = .auth
    }
}
