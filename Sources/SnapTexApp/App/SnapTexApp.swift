import Combine
import AppKit
import SwiftUI

@main
struct SnapTexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("snaptex", id: "main") {
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

        Window("Settings", id: "settings") {
            SettingsView(model: model)
                .frame(minWidth: 780, idealWidth: 900, minHeight: 520, idealHeight: 640)
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
        openWindow(id: "main")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openSettingsWindow() {
        openWindow(id: "settings")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
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
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
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
