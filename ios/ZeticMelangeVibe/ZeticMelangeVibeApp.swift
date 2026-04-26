import SwiftUI

@main
struct ZeticMelangeVibeApp: App {
    @State private var container: AppContainer = AppContainer.makeProduction()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appContainer, container)
                .preferredColorScheme(.light)
        }
    }
}
