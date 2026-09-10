import SwiftUI

@main
struct OllamaBridgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(appState: appState, proxy: appState.proxy)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        MenuBarExtra {
            MenuBarView(appState: appState, proxy: appState.proxy)
        } label: {
            Image(systemName: appState.proxy.isRunning ? "network" : "network.slash")
        }
        .menuBarExtraStyle(.window)
    }
}
