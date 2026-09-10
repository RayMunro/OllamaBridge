import Foundation

/// Streams a `POST /api/pull` request to a remote Ollama server and parses
/// its newline-delimited JSON progress events as they arrive.
final class ModelPuller: NSObject, ObservableObject, URLSessionDataDelegate {
    @Published var isPulling = false
    @Published var statusLine = ""
    @Published var progressFraction: Double?
    @Published var errorMessage: String?

    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var buffer = Data()

    func pull(model: String, host: String, port: String) {
        guard !isPulling else { return }

        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else {
            errorMessage = "Enter a model name"
            return
        }
        guard let portNumber = UInt16(port), !host.isEmpty else {
            errorMessage = "Set a valid remote host and port first"
            return
        }
        guard let url = URL(string: "http://\(host):\(portNumber)/api/pull") else {
            errorMessage = "Invalid host/port"
            return
        }

        errorMessage = nil
        statusLine = "Starting…"
        progressFraction = nil
        buffer = Data()
        isPulling = true

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["name": trimmedModel])

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 3600
        config.timeoutIntervalForResource = 3600 * 6
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session

        let task = session.dataTask(with: request)
        self.task = task
        task.resume()
    }

    func cancel() {
        task?.cancel()
        isPulling = false
        statusLine = "Cancelled"
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<newlineIndex]
            buffer.removeSubrange(buffer.startIndex...newlineIndex)
            if !lineData.isEmpty {
                handleLine(Data(lineData))
            }
        }
    }

    private func handleLine(_ lineData: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { return }

        let status = json["status"] as? String ?? ""
        let completed = (json["completed"] as? NSNumber)?.int64Value ?? 0
        let total = (json["total"] as? NSNumber)?.int64Value ?? 0
        let errorText = json["error"] as? String

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let errorText {
                self.errorMessage = errorText
                self.isPulling = false
                return
            }
            self.statusLine = status
            self.progressFraction = total > 0 ? Double(completed) / Double(total) : nil
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isPulling = false
            if let error, (error as NSError).code != NSURLErrorCancelled {
                self.errorMessage = error.localizedDescription
            } else if self.errorMessage == nil {
                self.statusLine = "Done"
                self.progressFraction = 1.0
            }
        }
    }
}
