import Foundation
import Network

/// Raw TCP pass-through proxy. Deliberately protocol-agnostic: it never parses
/// HTTP, so Ollama's streaming NDJSON responses, chunked transfer encoding,
/// and any future API endpoints all pass through untouched.
final class ProxyServer: ObservableObject {
    @Published var isRunning = false
    @Published var statusMessage = "Stopped"
    @Published var activeConnections = 0

    private var listener: NWListener?
    private let localPort: NWEndpoint.Port = 11434

    func start(remoteHostString: String, remotePortValue: UInt16) {
        stop()

        let remoteHost = NWEndpoint.Host(remoteHostString)
        guard let remotePort = NWEndpoint.Port(rawValue: remotePortValue) else {
            statusMessage = "Invalid remote port"
            return
        }

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        guard let newListener = try? NWListener(using: params, on: localPort) else {
            statusMessage = "Couldn't bind to :\(localPort) — is Ollama.app already running locally?"
            return
        }
        listener = newListener

        newListener.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }
                switch state {
                case .ready:
                    self.isRunning = true
                    self.statusMessage = "Forwarding :\(self.localPort) \u{2192} \(remoteHostString):\(remotePortValue)"
                case .failed(let error):
                    self.isRunning = false
                    self.statusMessage = "Failed: \(error.localizedDescription)"
                case .cancelled:
                    self.isRunning = false
                    self.statusMessage = "Stopped"
                default:
                    break
                }
            }
        }

        newListener.newConnectionHandler = { [weak self] clientConnection in
            self?.pair(clientConnection, withRemoteHost: remoteHost, remotePort: remotePort)
        }

        newListener.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        statusMessage = "Stopped"
        activeConnections = 0
    }

    private func pair(_ clientConnection: NWConnection, withRemoteHost host: NWEndpoint.Host, remotePort: NWEndpoint.Port) {
        let remoteConnection = NWConnection(host: host, port: remotePort, using: .tcp)

        activeConnections += 1

        var didCleanup = false
        let cleanup: () -> Void = { [weak self] in
            guard !didCleanup else { return }
            didCleanup = true
            clientConnection.cancel()
            remoteConnection.cancel()
            DispatchQueue.main.async {
                guard let self else { return }
                self.activeConnections = max(0, self.activeConnections - 1)
            }
        }

        clientConnection.stateUpdateHandler = { state in
            switch state {
            case .failed, .cancelled:
                cleanup()
            default:
                break
            }
        }
        remoteConnection.stateUpdateHandler = { state in
            switch state {
            case .failed, .cancelled:
                cleanup()
            default:
                break
            }
        }

        clientConnection.start(queue: .main)
        remoteConnection.start(queue: .main)

        pump(from: clientConnection, to: remoteConnection, onClose: cleanup)
        pump(from: remoteConnection, to: clientConnection, onClose: cleanup)
    }

    private func pump(from source: NWConnection, to destination: NWConnection, onClose: @escaping () -> Void) {
        source.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data, !data.isEmpty {
                destination.send(content: data, completion: .contentProcessed { _ in })
            }

            if isComplete || error != nil {
                onClose()
                return
            }

            self?.pump(from: source, to: destination, onClose: onClose)
        }
    }
}
