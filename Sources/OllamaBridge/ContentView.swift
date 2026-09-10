import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var proxy: ProxyServer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("OllamaBridge")
                    .font(.system(size: 22, weight: .bold))
                Text("© 2026 Raymond Munro")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(proxy.isRunning ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(proxy.statusMessage)
                    .font(.system(size: 13))
                    .lineLimit(2)
                Spacer()
            }

            GroupBox("Remote Ollama Server") {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("Host") {
                        TextField("192.168.1.100", text: $appState.remoteHost)
                            .textFieldStyle(.roundedBorder)
                            .disabled(proxy.isRunning)
                    }
                    LabeledContent("Port") {
                        TextField("11434", text: $appState.remotePort)
                            .textFieldStyle(.roundedBorder)
                            .disabled(proxy.isRunning)
                    }
                }
                .padding(8)
            }

            HStack {
                if proxy.isRunning {
                    Button("Stop") { appState.stop() }
                } else {
                    Button("Start") { appState.start() }
                        .keyboardShortcut(.defaultAction)
                }
                Spacer()
                if proxy.isRunning {
                    Text("\(proxy.activeConnections) active connection\(proxy.activeConnections == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VersionCheckView(appState: appState)

            ModelPickerView(appState: appState)

            PullModelView(appState: appState)

            GroupBox("General") {
                Toggle("Launch at login", isOn: $appState.launchAtLogin)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            Text("Apps on this Mac that connect to http://localhost:11434 will be transparently forwarded to the remote host above. Quit any local Ollama.app first — it holds that port.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 720)
    }
}
