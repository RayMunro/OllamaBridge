import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var proxy: ProxyServer
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(proxy.isRunning ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(proxy.statusMessage)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            if proxy.isRunning {
                Button("Stop") { appState.stop() }
            } else {
                Button("Start") { appState.start() }
            }

            Button("Open OllamaBridge…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }

            Divider()

            Button("Quit OllamaBridge") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 220)
    }
}
