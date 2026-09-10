import SwiftUI

struct VersionCheckView: View {
    @ObservedObject var appState: AppState
    @State private var version: String?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        GroupBox("Remote Ollama Version") {
            HStack(spacing: 10) {
                Button("Check Version") { checkVersion() }
                    .disabled(isLoading)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let version {
                    Text("v\(version)")
                        .font(.system(.body, design: .monospaced))
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding(8)
        }
    }

    private func checkVersion() {
        guard let portNumber = UInt16(appState.remotePort), !appState.remoteHost.isEmpty,
              let url = URL(string: "http://\(appState.remoteHost):\(portNumber)/api/version") else {
            errorMessage = "Invalid host/port"
            version = nil
            return
        }

        errorMessage = nil
        version = nil
        isLoading = true

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                let decoded = try JSONDecoder().decode(VersionResponse.self, from: data)
                await MainActor.run {
                    self.version = decoded.version
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

private struct VersionResponse: Decodable {
    let version: String
}
