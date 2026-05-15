import Combine
import AppKit
import SwiftUI

@main
struct SnapTexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("snaptex", id: "main") {
            ContentView(model: model)
                .frame(
                    minWidth: AppLayoutMetrics.mainWindowMinWidth,
                    minHeight: AppLayoutMetrics.mainWindowMinHeight
                )
                .onAppear {
                    appDelegate.configure(model: model)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    openSettingsWindow()
                }
                .keyboardShortcut(",")
            }

            CommandGroup(after: .newItem) {
                Button("Snip") {
                    model.snip()
                }
                .disabled(model.isProcessing)

                Button("Retry") {
                    model.retry()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!model.canRetry)
            }
        }

        MenuBarExtra {
            Button("Open snaptex") {
                openMainWindow()
            }
            .keyboardShortcut("o")

            Button("Settings") {
                openSettingsWindow()
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(systemName: "function")
        }
        .menuBarExtraStyle(.menu)
    }

    private func openMainWindow() {
        guard !bringWindowToFront(titled: "snaptex") else {
            return
        }

        openWindow(id: "main")
        DispatchQueue.main.async {
            bringWindowToFront(titled: "snaptex")
        }
    }

    private func openSettingsWindow() {
        SettingsWindowPresenter.show(model: model)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotKeyController = GlobalHotKeyController()
    private var cancellables = Set<AnyCancellable>()
    private weak var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            bringWindowToFront(titled: "snaptex")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.setActivationPolicy(.regular)
        if !flag {
            if !bringWindowToFront(titled: "snaptex") {
                sender.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func configure(model: AppModel) {
        guard self.model !== model else {
            return
        }

        self.model = model
        hotKeyController.action = { [weak model] in
            model?.snip()
        }

        cancellables.removeAll()
        model.$settings
            .map(\.snipShortcut)
            .removeDuplicates()
            .sink { [weak self, weak model] shortcut in
                Task { @MainActor in
                    guard let self else {
                        return
                    }
                    let didRegister = self.hotKeyController.register(shortcut)
                    if !didRegister {
                        model?.status = "Shortcut unavailable: \(shortcut.displayText)"
                    }
                }
            }
            .store(in: &cancellables)
    }
}

@discardableResult
@MainActor
private func bringWindowToFront(titled title: String) -> Bool {
    guard let window = NSApp.windows.first(where: { $0.title == title && $0.canBecomeMain }) else {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        return false
    }

    NSApp.setActivationPolicy(.regular)
    if window.isMiniaturized {
        window.deminiaturize(nil)
    }
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    return true
}

@MainActor
enum SettingsWindowPresenter {
    private static var window: NSWindow?

    static func show(model: AppModel) {
        if let window {
            bring(window)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView(model: model)
                .frame(minWidth: 780, idealWidth: 900, minHeight: 520, idealHeight: 640)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 900, height: 640))
        window.isReleasedWhenClosed = false
        self.window = window
        bring(window)
    }

    private static func bring(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    #if DEBUG
    static func closeForTesting() {
        window?.close()
        window = nil
    }
    #endif
}
