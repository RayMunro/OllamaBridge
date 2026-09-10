import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Closing the main window shouldn't quit the app — it keeps running
    // via the menu bar icon, same as a normal background utility.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
