import SwiftUI

struct ContentView: View {
    @StateObject var meshManager = MeshNetworkManager()
    @State private var showScanner = false
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1.0)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        Group {
            if !meshManager.hasAccess {
                AuthView().environmentObject(meshManager)
            } else {
                TabView {
                    NavigationView {
                        ChatListContainer(showScanner: $showScanner).environmentObject(meshManager)
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem { Label("Сеть", systemImage: "bolt.horizontal.circle.fill") }
                    
                    NavigationView {
                        SettingsView().environmentObject(meshManager)
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem { Label("Штаб", systemImage: "cpu.fill") }
                }.accentColor(.cyan)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showScanner) {
            QRScannerView { code in meshManager.handleExternalQR(code) }
        }
    }
}

struct ChatListContainer: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    @Binding var showScanner: Bool

    var body: some View {
        ZStack {
            Color(red: 0.01, green: 0.02, blue: 0.06).ignoresSafeArea()
            
            if meshManager.contacts.isEmpty {
                VStack(spacing: 30) {
                    ZStack {
                        Circle().fill(Color.cyan.opacity(0.1)).frame(width: 150, height: 150)
                        Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 60)).foregroundColor(.cyan)
                    }
                    Text("Сектор пуст").font(.title2.bold())
                    Text("Обнаружение узлов активно. Сканируйте QR или ждите появления соседей.").multilineTextAlignment(.center).foregroundColor(.gray).padding(.horizontal, 40)
                    
                    Button(action: { showScanner = true }) {
                        Label("Сканировать Узел", systemImage: "qrcode.viewfinder").font(.headline).foregroundColor(.black).padding().background(Color.cyan).cornerRadius(18)
                    }
                }
            } else {
                List {
                    ForEach(meshManager.contacts) { contact in
                        NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                            ContactCell(contact: contact)
                        }
                        .listRowBackground(Color.white.opacity(0.03))
                    }
                    .onDelete { indexSet in /* Logic for removal */ }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .navigationTitle("HQ Global")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showScanner = true }) {
                    Image(systemName: "qrcode.viewfinder").font(.title3).foregroundColor(.cyan)
                }
            }
        }
    }
}

struct ContactCell: View {
    let contact: Contact
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 55, height: 55)
                Text(String(contact.name.prefix(1)).uppercased()).font(.title2.bold()).foregroundColor(.white)
                
                Circle().stroke(Color.black, lineWidth: 3).background(Circle().fill(Color.green)).frame(width: 14, height: 14).offset(x: 18, y: 18)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(contact.name).font(.headline).foregroundColor(.white)
                Text("ID: " + contact.hqId).font(.caption.monospaced()).foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray.opacity(0.5))
        }.padding(.vertical, 8)
    }
}