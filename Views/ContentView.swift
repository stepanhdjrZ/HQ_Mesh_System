import SwiftUI

struct ContentView: View {
    @StateObject var meshManager = MeshNetworkManager()
    @State private var showingScanner = false
    @State private var scannedID: String? = nil
    
    // Кастомный цвет для фона как в ТГ
    let tgBackground = Color(UIColor.systemGroupedBackground)
    
    var body: some View {
        TabView {
            // --- ВКЛАДКА 1: КОНТАКТЫ ---
            NavigationView {
                List {
                    // Кнопка добавления нового контакта
                    Button(action: { showingScanner = true }) {
                        HStack(spacing: 16) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 32)
                            Text("Добавить контакт")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Список контактов
                    if !meshManager.contacts.isEmpty {
                        ForEach(meshManager.contacts) { contact in
                            NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                                HStack(spacing: 12) {
                                    // Аватарка градиентная
                                    Circle()
                                        .fill(LinearGradient(gradient: Gradient(colors: [.cyan, .blue]), startPoint: .top, endPoint: .bottom))
                                        .frame(width: 40, height: 40)
                                        .overlay(Text(String(contact.hqId.prefix(1))).font(.system(size: 16, weight: .semibold)).foregroundColor(.white))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact.hqId)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Text("в сети")
                                            .font(.system(size: 14))
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .navigationTitle("Контакты")
                .navigationBarTitleDisplayMode(.inline) // Делает шапку компактной как в ТГ
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Text("Сортировка").foregroundColor(.blue) }
                    ToolbarItem(placement: .navigationBarTrailing) { Image(systemName: "plus").foregroundColor(.blue) }
                }
                .sheet(isPresented: $showingScanner) {
                    VStack {
                        HStack { Spacer(); Button("Отмена") { showingScanner = false }.padding() }
                        QRScannerView { result in
                            if result.contains("HQ-") { scannedID = result; showingScanner = false }
                        }
                    }
                }
                .background(
                    NavigationLink(destination: ChatView(contactID: scannedID ?? "").environmentObject(meshManager), isActive: Binding(get: { scannedID != nil }, set: { if !$0 { scannedID = nil } })) { EmptyView() }
                )
            }
            .tabItem { Label("Контакты", systemImage: "person.circle.fill") }
            
            // --- ВКЛАДКА 2: ЧАТЫ (ГЛАВНАЯ) ---
            NavigationView {
                List {
                    if meshManager.contacts.isEmpty {
                        Text("У вас пока нет чатов. Перейдите в Контакты.")
                            .foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .center).padding(.top, 50)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(meshManager.contacts) { contact in
                            NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                                HStack(spacing: 12) {
                                    // Большая аватарка чата
                                    Circle()
                                        .fill(LinearGradient(gradient: Gradient(colors: [.purple, .indigo]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 50, height: 50)
                                        .overlay(Text(String(contact.hqId.prefix(1))).font(.system(size: 20, weight: .bold)).foregroundColor(.white))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(alignment: .top) {
                                            Text(contact.hqId)
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundColor(.primary)
                                            Spacer()
                                            // Время последнего сообщения
                                            Text("21:45")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                        }
                                        
                                        HStack {
                                            // Превью сообщения
                                            Text("Защищенное соединение установлено...")
                                                .font(.system(size: 15))
                                                .foregroundColor(.gray)
                                                .lineLimit(2)
                                                .truncationMode(.tail)
                                            Spacer()
                                            // Значок непрочитанного
                                            Circle()
                                                .fill(Color.blue)
                                                .frame(width: 22, height: 22)
                                                .overlay(Text("1").font(.system(size: 13, weight: .bold)).foregroundColor(.white))
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .navigationTitle("Чаты")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Text("Изм.").foregroundColor(.blue) }
                    ToolbarItem(placement: .navigationBarTrailing) { Image(systemName: "square.and.pencil").foregroundColor(.blue) }
                    
                    // Центральный статус коннекта под заголовком
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 0) {
                            Text("Чаты").font(.headline)
                            Text(meshManager.connectionState == .connected ? "Обновление..." : "Ожидание сети...")
                                .font(.caption2)
                                .foregroundColor(meshManager.connectionState == .connected ? .gray : .orange)
                        }
                    }
                }
            }
            .tabItem { Label("Чаты", systemImage: "message.fill") }
            
            // --- ВКЛАДКА 3: НАСТРОЙКИ ---
            SettingsView()
                .environmentObject(meshManager)
                .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
        }
    }
}
