import SwiftUI

struct DiscoverOllamaView: View {
    @ObservedObject var appState: AppState
    @StateObject private var scanner = NetworkScanner()
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
            scanner.scan()
        } label: {
            Image(systemName: "magnifyingglass")
        }
        .help("Find Ollama servers on this network")
        .sheet(isPresented: $isPresented) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ollama servers on this network")
                    .font(.headline)

                if scanner.isScanning {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Scanning…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else if let errorMessage = scanner.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if !scanner.results.isEmpty {
                    List(scanner.results) { result in
                        Button {
                            appState.remoteHost = result.host
                            appState.remotePort = "11434"
                            isPresented = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(result.host)
                                        .font(.system(.body, design: .monospaced))
                                    Text("v\(result.version)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.inset)
                    .frame(minHeight: 120)
                }

                HStack {
                    Button("Rescan") { scanner.scan() }
                        .disabled(scanner.isScanning)
                    Spacer()
                    Button("Close") { isPresented = false }
                }
            }
            .padding(20)
            .frame(width: 360, height: 320)
        }
    }
}
