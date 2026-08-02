import SwiftUI

@main
struct WeatherAppApp: App {
    // 1. Beyni (ViewModel) uygulamanın en tepesinde TEK BİR KERE yaratıyoruz.
    @StateObject private var viewModel = WeatherViewModel()
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                // 2. Bu beyni tüm alt ekranların erişebileceği bir "Ortam Nesnesi" yapıyoruz.
                .environmentObject(viewModel)
        }
    }
}
