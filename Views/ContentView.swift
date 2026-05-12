import SwiftUI
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @StateObject var meshManager = MeshNetworkManager()
    
    var body: some View {
        TabView {
            // ВКЛАДКА 1: ЧАТЫ
            NavigationView {
                List {
                    // Пока сделаем кнопку для начала чата по ID
                    NavigationLink(destination: ChatView(contactID: "Введите ID контакта").environmentObject(meshManager)) {
                        HStack(spacing: 15) {
                            Circle()
                                .fill(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 50, height: 50)
                                .overlay(Text("➕").foregroundColor(.white))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Новый чат")
                                    .font(.headline)
                                Text("Начать общение по HQ ID")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Чаты")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Text(meshManager.isConnected ? "Подключено" : "Соединение...")
                            .font(.caption)
                            .foregroundColor(meshManager.isConnected ? .green : .red)
                    }
                }
            }
            .tabItem {
                Label("Чаты", systemImage: "message.fill")
            }
            
            // ВКЛАДКА 2: ПРОФИЛЬ И QR КОД
            NavigationView {
                VStack(spacing: 30) {
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Text("Твой HQ ID")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(meshManager.myHQID)
                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                    }
                    
                    // Генерация QR-кода
                    Image(uiImage: generateQRCode(from: meshManager.myHQID))
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(radius: 10)
                    
                    Text("Дай отсканировать этот код или отправь свой ID другу, чтобы начать защищенный чат.")
                        .multilineTextAlignment(.center)
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
                .navigationTitle("Профиль")
            }
            .tabItem {
                Label("Профиль", systemImage: "person.crop.circle")
            }
        }
    }
    
    // Функция создания QR-кода на лету
    func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")

        if let outputImage = filter.outputImage {
            if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}
