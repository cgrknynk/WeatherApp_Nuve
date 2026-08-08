import SwiftUI

// MARK: - boş/hatalı durumlarda gösterilen küçük uyarı kartı
// sadece ikon + mesaj gösteriyor. eskiden içine bir de opsiyonel "tekrar
// dene" butonu koymuştum ama hiçbir çağrı yeri bu butonu hiç kullanmadı
// (favori listesi boş, konum izni yok, arama sonucu yok gibi durumların
// hepsi sadece bilgilendiriyor), o yüzden kullanılmayan kısmı kaldırdım
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
        // sadece önizlemede görünsün diye arkaya geçici bir renk koydum
        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

        GlassWarningView(
            iconName: "wifi.slash",
            message: "İnternet bağlantınız koptu veya sunucu yanıt vermiyor."
        )
    }
}
