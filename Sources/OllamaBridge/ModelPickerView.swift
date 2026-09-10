import SwiftUI

/// Lets the user pick a "preferred" model from what's installed on the
/// remote Ollama. Ollama itself has no server-side notion of an active
/// model — every request names its own model — so this is just a
/// remembered choice this app displays for convenience.
struct ModelPickerView: View {
    @ObservedObject var appState: AppState
    @State private var models: [String] = []
    @State private var isLoading = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        GroupBox("Model") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Picker("Model", selection: $appState.selectedModel) {
                        if appState.selectedModel.isEmpty {
                            Text("None selected").tag("")
                        }
                        ForEach(models, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .labelsHidden()
                    .disabled(models.isEmpty)

                    Button {
                        refresh()
                    } label: {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isLoading || isDeleting)
                    .help("Refresh model list")

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        if isDeleting {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "trash")
                        }
                    }
                    .disabled(appState.selectedModel.isEmpty || isDeleting || isLoading)
                    .help("Delete this model from the remote server")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if models.isEmpty && !isLoading {
                    Text("No models found — pull one below, then refresh.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Models directory") {
                    TextField("/mnt/user/appdata/ollama/models", text: $appState.modelsBasePath)
                        .textFieldStyle(.roundedBorder)
                }

                if !appState.selectedModel.isEmpty,
                   let path = OllamaModelPath.manifestPath(forModel: appState.selectedModel, modelsDirectory: appState.modelsBasePath) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manifest path")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(path)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
            }
            .padding(8)
        }
        .task { refresh() }
        .alert("Delete \(appState.selectedModel)?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteSelectedModel() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the model from the remote server. It will need to be downloaded again to use it.")
        }
    }

    private func refresh(retryOnColdStart: Bool = true) {
        guard let portNumber = UInt16(appState.remotePort), !appState.remoteHost.isEmpty,
              let url = URL(string: "http://\(appState.remoteHost):\(portNumber)/api/tags") else {
            errorMessage = "Invalid host/port"
            return
        }

        errorMessage = nil
        isLoading = true

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
                await MainActor.run {
                    self.models = decoded.models.map(\.name).sorted()
                    if !self.models.isEmpty, !self.models.contains(appState.selectedModel) {
                        appState.selectedModel = self.models[0]
                    }
                    self.isLoading = false
                }
            } catch let error as URLError where error.code == .notConnectedToInternet && retryOnColdStart {
                // Right after a fresh launch, URLSession can spuriously report
                // "not connected" for a moment before the network path comes
                // up. Retry once before surfacing it as a real error.
                try? await Task.sleep(nanoseconds: 700_000_000)
                refresh(retryOnColdStart: false)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func deleteSelectedModel() {
        let modelToDelete = appState.selectedModel
        guard let portNumber = UInt16(appState.remotePort), !appState.remoteHost.isEmpty,
              let url = URL(string: "http://\(appState.remoteHost):\(portNumber)/api/delete"),
              !modelToDelete.isEmpty else {
            errorMessage = "Invalid host/port"
            return
        }

        errorMessage = nil
        isDeleting = true

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["name": modelToDelete])

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard httpResponse.statusCode == 200 else {
                    let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                    throw NSError(domain: "OllamaBridge", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: message ?? "Delete failed (HTTP \(httpResponse.statusCode))"
                    ])
                }
                await MainActor.run {
                    self.isDeleting = false
                    if appState.selectedModel == modelToDelete {
                        appState.selectedModel = ""
                    }
                    refresh()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isDeleting = false
                }
            }
        }
    }
}

private struct TagsResponse: Decodable {
    let models: [ModelTag]
}

private struct ModelTag: Decodable {
    let name: String
}
