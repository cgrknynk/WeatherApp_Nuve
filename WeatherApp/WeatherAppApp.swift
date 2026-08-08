import SwiftUI

@main
struct WeatherAppApp: App {
    // viewmodel'i uygulamanın en tepesinde tek bir kere yaratıyorum
    @StateObject private var viewModel = WeatherViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                // bu viewmodel'i tüm alt ekranların erişebileceği bir ortam nesnesi yapıyorum
                .environmentObject(viewModel)
                // uygulama zaten hep koyu bir arka plan + açık renkli yazı
                // varsayıyor. telefon açık moddayken bazı sistem kontrolleri
                // (picker etiketi gibi) kendi açık mod renklerine dönüp bazı
                // yazılar siyah çıkıyordu. o yüzden sistem ayarından bağımsız
                // olarak uygulamayı hep koyu modda sabitliyorum
                .preferredColorScheme(.dark)
        }
    }
}
