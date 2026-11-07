import SwiftUI

@main struct WordCrushManiaApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in model.sceneChanged(phase) }
        }
    }
}
