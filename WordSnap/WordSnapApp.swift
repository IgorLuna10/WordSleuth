import SwiftUI

@main
struct WordSnapApp: App {
    @StateObject private var stateManager = AppStateManager()

    init() {
        AdMobManager.shared.startSDK()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(stateManager)
                .preferredColorScheme(.dark)
        }
    }
}
