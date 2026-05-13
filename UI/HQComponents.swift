import SwiftUI

// MARK: - Анонимный радар плотности сети
struct RadarView: View {
    let activeNodesCount: Int
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    .frame(width: 100, height: 100)
                Circle().stroke(Color.cyan.opacity(0.1), lineWidth: 1)
                    .frame(width: 150, height: 150)
                
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 30))
                    .foregroundColor(activeNodesCount > 0 ? .cyan : .gray)
            }
            
            Text("АКТИВНЫЕ РЕТРАНСЛЯТОРЫ: \(activeNodesCount)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(activeNodesCount > 0 ? .cyan : .gray)
            
            Text("Режим невидимости активирован. Ваши данные зашифрованы.")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
    }
}
