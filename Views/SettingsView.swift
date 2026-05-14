import SwiftUI

struct SettingsView: View {
    // Настоящие переменные, сохраняющиеся в памяти телефона
    @AppStorage("isMeshEnabled") private var isMeshEnabled = true
    @AppStorage("isStealthMode") private var isStealthMode = false
    @AppStorage("allowBackgroundRouting") private var allowBackgroundRouting = true
    @AppStorage("saveMediaToGallery") private var saveMediaToGallery = false
    
    var body: some View {
        NavigationView {
            Form {
                // ПРОФИЛЬ УЗЛА
                Section(header: Text("Профиль узла")) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.cyan)
                        VStack(alignment: .leading) {
                            Text("Позывной: Emperor")
                                .font(.headline)
                            Text("ID: 8899-AABB-CCDD")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 5)
                }
                
                // MESH-СЕТЬ
                Section(header: Text("Маршрутизация сети"), footer: Text("В скрытом режиме ваш узел передает транзитные пакеты, но не отображается на радарах других пользователей.")) {
                    Toggle(isOn: $isMeshEnabled) {
                        Label("Активный узел (Mesh)", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .tint(.cyan)
                    
                    Toggle(isOn: $allowBackgroundRouting) {
                        Label("Фоновая ретрансляция", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .tint(.cyan)
                    
                    Toggle(isOn: $isStealthMode) {
                        Label("Скрытый режим (Stealth)", systemImage: "eye.slash")
                    }
                    .tint(.cyan)
                    .disabled(!isMeshEnabled)
                }
                
                // ДАННЫЕ И ПАМЯТЬ
                Section(header: Text("Данные и память")) {
                    Toggle(isOn: $saveMediaToGallery) {
                        Label("Сохранять фото в галерею", systemImage: "photo.on.rectangle")
                    }
                    
                    Button(action: {
                        // Логика очистки кэша
                    }) {
                        HStack {
                            Text("Очистить кэш базы данных")
                                .foregroundColor(.red)
                            Spacer()
                            Text("24 MB")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // ИНФОРМАЦИЯ (ДЛЯ APPLE)
                Section(header: Text("Информация")) {
                    NavigationLink(destination: Text("Здесь будет текст EULA...").padding()) {
                        Text("Пользовательское соглашение (EULA)")
                    }
                    NavigationLink(destination: Text("Версия ядра Империи: 1.0.0").padding()) {
                        Text("О приложении")
                    }
                }
            }
            .navigationTitle("Настройки")
            .preferredColorScheme(.dark) 
        }
    }
}
