import AppKit
import MagnifyCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config: Config
    private var controller: AppController?

    init(config: Config) {
        self.config = config
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = DisplayManager.screenContainingCursor()
                ?? NSScreen.main
                ?? NSScreen.screens.first else {
            errPrint("No display found.")
            NSApp.terminate(nil)
            return
        }
        let controller = AppController(config: config, screen: screen)
        controller.start()
        self.controller = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }
}

let config = Config.parse(CommandLine.arguments)

let app = NSApplication.shared
let delegate = AppDelegate(config: config)
app.delegate = delegate
app.setActivationPolicy(.accessory) // no Dock icon; still shows windows

// Quit cleanly on Ctrl-C from the launching terminal.
signal(SIGINT, SIG_IGN)
let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigintSource.setEventHandler { NSApp.terminate(nil) }
sigintSource.resume()

app.run()
