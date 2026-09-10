import Foundation

final class AppState: ObservableObject {
    @Published var remoteHost: String {
        didSet { UserDefaults.standard.set(remoteHost, forKey: "remoteHost") }
    }
    @Published var remotePort: String {
        didSet { UserDefaults.standard.set(remotePort, forKey: "remotePort") }
    }
    @Published var launchAtLogin: Bool {
        didSet { LoginItemManager.setEnabled(launchAtLogin) }
    }
    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "selectedModel") }
    }
    @Published var modelsBasePath: String {
        didSet { UserDefaults.standard.set(modelsBasePath, forKey: "modelsBasePath") }
    }

    let proxy = ProxyServer()

    init() {
        remoteHost = UserDefaults.standard.string(forKey: "remoteHost") ?? "192.168.1.100"
        remotePort = UserDefaults.standard.string(forKey: "remotePort") ?? "11434"
        launchAtLogin = LoginItemManager.isEnabled
        selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? ""
        modelsBasePath = UserDefaults.standard.string(forKey: "modelsBasePath") ?? ""
    }

    func start() {
        guard let portValue = UInt16(remotePort) else {
            proxy.statusMessage = "Invalid port"
            return
        }
        proxy.start(remoteHostString: remoteHost, remotePortValue: portValue)
    }

    func stop() {
        proxy.stop()
    }
}
