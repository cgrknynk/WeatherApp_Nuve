import SwiftUI

struct GlassWarningView: View {
    var iconName: String
    var message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.white)

            Text(message)
                .font(.weatherBody)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .weatherGlassCard()
        .padding(.horizontal)
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

        GlassWarningView(
            iconName: "wifi.slash",
            message: "İnternet bağlantınız koptu veya sunucu yanıt vermiyor."
        )
    }
}
