import SwiftUI

struct PullModelView: View {
    @ObservedObject var appState: AppState
    @StateObject private var puller = ModelPuller()
    @State private var modelName: String = ""

    var body: some View {
        GroupBox("Download a Model") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField("e.g. llama3.2:3b", text: $modelName)
                        .textFieldStyle(.roundedBorder)
                        .disabled(puller.isPulling)
                        .onSubmit(startPull)

                    if puller.isPulling {
                        Button("Cancel") { puller.cancel() }
                    } else {
                        Button("Pull") { startPull() }
                            .disabled(modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if puller.isPulling || puller.progressFraction != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        if let fraction = puller.progressFraction {
                            ProgressView(value: fraction)
                        } else {
                            ProgressView()
                        }
                        Text(puller.statusLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = puller.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(8)
        }
    }

    private func startPull() {
        guard !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        puller.pull(model: modelName, host: appState.remoteHost, port: appState.remotePort)
    }
}
