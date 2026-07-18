import AppKit
import Darwin

if let request = SnapshotRenderer.request(from: CommandLine.arguments) {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    Task { @MainActor in
        do {
            try SnapshotRenderer.render(request)
            exit(EXIT_SUCCESS)
        } catch {
            fputs("Snapshot render failed: \(error)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }
    app.run()
}

let app = NSApplication.shared
let appDelegate = AppDelegate()

app.delegate = appDelegate
app.setActivationPolicy(.accessory)
app.run()
