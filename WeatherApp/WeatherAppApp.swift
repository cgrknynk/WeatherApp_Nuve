import SwiftUI

@main
struct WeatherAppApp: App {
    @StateObject private var viewModel = WeatherViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(viewModel)
                .preferredColorScheme(.dark) // uygulama hep koyu modda kalsın
        }
    }
}
