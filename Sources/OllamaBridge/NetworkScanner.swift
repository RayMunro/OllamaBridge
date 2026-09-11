import Foundation

struct DiscoveredOllama: Identifiable, Hashable {
    var id: String { host }
    let host: String
    let version: String
}

/// Ollama has no discovery protocol (no mDNS/Bonjour advertisement), so the
/// only way to find instances on the LAN is to probe hosts directly. This
/// sweeps the /24 subnet of the Mac's active network interface, hitting
/// `/api/version` on each address with a short timeout.
final class NetworkScanner: ObservableObject {
    @Published var isScanning = false
    @Published var results: [DiscoveredOllama] = []
    @Published var errorMessage: String?

    private let port: UInt16 = 11434

    func scan() {
        guard !isScanning else { return }
        results = []
        errorMessage = nil
        isScanning = true

        Task {
            guard let localIP = Self.currentIPv4Address() else {
                await MainActor.run {
                    self.errorMessage = "Couldn't determine this Mac's local network address"
                    self.isScanning = false
                }
                return
            }

            let prefix = Self.subnetPrefix(from: localIP)
            let port = self.port

            let found = await withTaskGroup(of: DiscoveredOllama?.self, returning: [DiscoveredOllama].self) { group in
                for i in 1...254 {
                    let host = "\(prefix).\(i)"
                    group.addTask {
                        await Self.probe(host: host, port: port)
                    }
                }
                var collected: [DiscoveredOllama] = []
                for await result in group {
                    if let result {
                        collected.append(result)
                    }
                }
                return collected
            }

            await MainActor.run {
                self.results = found.sorted { $0.host < $1.host }
                self.isScanning = false
                if found.isEmpty {
                    self.errorMessage = "No Ollama instances found on \(prefix).0/24"
                }
            }
        }
    }

    private static func probe(host: String, port: UInt16) async -> DiscoveredOllama? {
        guard let url = URL(string: "http://\(host):\(port)/api/version") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.6

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.6
        config.timeoutIntervalForResource = 1.0
        let session = URLSession(configuration: config)

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }
        let version = (try? JSONDecoder().decode(VersionPayload.self, from: data))?.version ?? "unknown"
        return DiscoveredOllama(host: host, version: version)
    }

    private struct VersionPayload: Decodable { let version: String }

    private static func currentIPv4Address() -> String? {
        var address: String?
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: interface.ifa_name)
            guard name.hasPrefix("en") else { continue }

            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST)
            let ip = String(cString: hostBuffer)
            if ip != "127.0.0.1" {
                address = ip
                if name == "en0" { break }
            }
        }
        return address
    }

    private static func subnetPrefix(from ip: String) -> String {
        ip.split(separator: ".").prefix(3).joined(separator: ".")
    }
}
