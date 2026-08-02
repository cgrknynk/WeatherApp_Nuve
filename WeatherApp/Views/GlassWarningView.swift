import SwiftUI

struct GlassWarningView: View {
    var iconName: String
    var message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.white)
            
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
            
            // Eğer bir aksiyon butonu tanımlanmışsa göster (Örn: "Tekrar Dene")
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.bold())
                        .foregroundColor(.blue)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(20)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        // İşin sırrı buradaki glassmorphism efektinde:
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}

#Preview {
    ZStack {
        // Test etmek için arkaya geçici bir gradyan koyuyoruz
        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        
        GlassWarningView(
            iconName: "wifi.slash",
            message: "İnternet bağlantınız koptu veya sunucu yanıt vermiyor.",
            actionTitle: "Tekrar Dene"
        ) {
            print("Yeniden deneme butonu tıklandı!")
        }
    }
}
