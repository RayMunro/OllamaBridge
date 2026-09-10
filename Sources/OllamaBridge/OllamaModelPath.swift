import Foundation

/// Ollama has no API to ask "where is this model on disk" — it stores
/// content-addressed blobs shared across models, plus a small per-model
/// manifest file at a predictable path. This reconstructs that manifest
/// path from the model's name and the configured models directory.
enum OllamaModelPath {
    static func manifestPath(forModel model: String, modelsDirectory: String) -> String? {
        let trimmedDir = modelsDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDir.isEmpty, !trimmedModel.isEmpty else { return nil }

        var name = trimmedModel
        var tag = "latest"
        if let colonIndex = name.lastIndex(of: ":") {
            tag = String(name[name.index(after: colonIndex)...])
            name = String(name[..<colonIndex])
        }

        var namespace = "library"
        if let slashIndex = name.lastIndex(of: "/") {
            namespace = String(name[..<slashIndex])
            name = String(name[name.index(after: slashIndex)...])
        }

        let base = trimmedDir.hasSuffix("/") ? String(trimmedDir.dropLast()) : trimmedDir
        return "\(base)/manifests/registry.ollama.ai/\(namespace)/\(name)/\(tag)"
    }
}
