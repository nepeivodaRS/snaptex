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
            ZStack {
                AppTheme.windowBackground.ignoresSafeArea()

                ContentView(model: model)
                    .frame(
                        minWidth: AppLayoutMetrics.mainWindowMinWidth,
                        minHeight: AppLayoutMetrics.mainWindowMinHeight
                    )
                    .background(
                        ZStack {
                            WindowChromeConfigurator(hidesTitle: true, titlebarTitle: "snaptex")
                                .frame(width: 0, height: 0)

                            WindowMinimumSizeEnforcer(
                                minSize: NSSize(
                                    width: AppLayoutMetrics.mainWindowMinWidth,
                                    height: AppLayoutMetrics.mainWindowMinHeight
                                )
                            )
                            .frame(width: 0, height: 0)
                        }
                    )
            }
            .onAppear {
                appDelegate.configure(model: model, openMainWindow: {
                    openMainWindow()
                })
            }
        }
        .windowStyle(.hiddenTitleBar)
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
            Image(nsImage: MenuBarIconImage.make())
            .accessibilityLabel("snaptex")
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
    private let snipHotKeyController = GlobalHotKeyController()
    private let openAppHotKeyController = GlobalHotKeyController(hotKeyID: 2)
    private var cancellables = Set<AnyCancellable>()
    private weak var model: AppModel?
    private var openMainWindowAction: (() -> Void)?

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

    func configure(model: AppModel, openMainWindow: @escaping () -> Void) {
        openMainWindowAction = openMainWindow
        guard self.model !== model else {
            return
        }

        self.model = model
        snipHotKeyController.action = { [weak model] in
            model?.snip()
        }
        openAppHotKeyController.action = { [weak self] in
            self?.openMainWindowAction?()
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
                    let didRegister = self.snipHotKeyController.register(shortcut)
                    if !didRegister {
                        model?.status = "Snip shortcut unavailable: \(shortcut.displayText)"
                    }
                }
            }
            .store(in: &cancellables)

        model.$settings
            .map(\.openAppShortcut)
            .removeDuplicates()
            .sink { [weak self, weak model] shortcut in
                Task { @MainActor in
                    guard let self else {
                        return
                    }
                    let didRegister = self.openAppHotKeyController.register(shortcut)
                    if !didRegister {
                        model?.status = "Open app shortcut unavailable: \(shortcut.displayText)"
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
    configureWindowChrome(
        window,
        hidesTitle: title == "snaptex",
        titlebarTitle: title == "snaptex" ? "snaptex" : nil
    )
    if window.isMiniaturized {
        window.deminiaturize(nil)
    }
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    return true
}

private struct WindowMinimumSizeEnforcer: NSViewRepresentable {
    let minSize: NSSize

    func makeNSView(context: Context) -> MinimumSizeView {
        MinimumSizeView(minSize: minSize)
    }

    func updateNSView(_ view: MinimumSizeView, context: Context) {
        view.minSize = minSize
    }

    final class MinimumSizeView: NSView {
        var minSize: NSSize {
            didSet {
                enforceMinimumSize()
            }
        }

        init(minSize: NSSize) {
            self.minSize = minSize
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            enforceMinimumSize()
        }

        private func enforceMinimumSize() {
            guard let window else {
                return
            }

            window.contentMinSize = minSize

            guard let contentSize = window.contentView?.bounds.size else {
                return
            }

            let clampedContentSize = NSSize(
                width: max(contentSize.width, minSize.width),
                height: max(contentSize.height, minSize.height)
            )

            if clampedContentSize.width > contentSize.width
                || clampedContentSize.height > contentSize.height {
                window.setContentSize(clampedContentSize)
            }
        }
    }
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
                .frame(
                    minWidth: AppLayoutMetrics.settingsWindowMinWidth,
                    idealWidth: AppLayoutMetrics.settingsWindowIdealWidth,
                    minHeight: AppLayoutMetrics.settingsWindowMinHeight,
                    idealHeight: AppLayoutMetrics.settingsWindowIdealHeight
                )
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        configureWindowChrome(window)
        window.contentMinSize = NSSize(
            width: AppLayoutMetrics.settingsWindowMinWidth,
            height: AppLayoutMetrics.settingsWindowMinHeight
        )
        window.setContentSize(NSSize(
            width: AppLayoutMetrics.settingsWindowIdealWidth,
            height: AppLayoutMetrics.settingsWindowIdealHeight
        ))
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

private struct WindowChromeConfigurator: NSViewRepresentable {
    let hidesTitle: Bool
    let titlebarTitle: String?

    func makeNSView(context: Context) -> ChromeView {
        ChromeView(hidesTitle: hidesTitle, titlebarTitle: titlebarTitle)
    }

    func updateNSView(_ view: ChromeView, context: Context) {
        view.hidesTitle = hidesTitle
        view.titlebarTitle = titlebarTitle
        view.configureWindow()
    }

    final class ChromeView: NSView {
        var hidesTitle: Bool
        var titlebarTitle: String?

        init(hidesTitle: Bool, titlebarTitle: String?) {
            self.hidesTitle = hidesTitle
            self.titlebarTitle = titlebarTitle
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureWindow()
        }

        func configureWindow() {
            guard let window else {
                return
            }
            configureWindowChrome(window, hidesTitle: hidesTitle, titlebarTitle: titlebarTitle)
        }
    }
}

@MainActor
private func configureWindowChrome(
    _ window: NSWindow,
    hidesTitle: Bool = false,
    titlebarTitle: String? = nil
) {
    window.styleMask.insert(.fullSizeContentView)
    window.backgroundColor = AppTheme.windowBackgroundNSColor
    window.titleVisibility = hidesTitle ? .hidden : .visible
    window.titlebarAppearsTransparent = true
    window.titlebarSeparatorStyle = .none
    window.isMovableByWindowBackground = true
    window.appearance = NSAppearance(named: .darkAqua)
    window.contentView?.wantsLayer = true
    window.contentView?.layer?.backgroundColor = AppTheme.windowBackgroundNSColor.cgColor
    configureTitlebarBackground(for: window)
    configureTitlebarTitle(for: window, title: titlebarTitle)
}

@MainActor
private func configureTitlebarBackground(for window: NSWindow) {
    let titlebarViews = [
        window.standardWindowButton(.closeButton)?.superview?.superview,
        window.standardWindowButton(.closeButton)?.superview
    ]

    for view in titlebarViews.compactMap({ $0 }) {
        view.wantsLayer = true
        view.layer?.backgroundColor = AppTheme.windowBackgroundNSColor.cgColor
    }
}

@MainActor
private func configureTitlebarTitle(for window: NSWindow, title: String?) {
    let identifier = NSUserInterfaceItemIdentifier("SnapTexTitlebarTitle")
    let accessoryControllers = window.titlebarAccessoryViewControllers
    for index in accessoryControllers.indices.reversed() where accessoryControllers[index].view.identifier == identifier {
        window.removeTitlebarAccessoryViewController(at: index)
    }

    guard let title else {
        return
    }

    let titleView = NSView(frame: NSRect(
        x: 0,
        y: 0,
        width: AppLayoutMetrics.mainWindowTitlebarTitleWidth,
        height: AppLayoutMetrics.mainWindowTitlebarHeight
    ))
    titleView.identifier = identifier
    titleView.wantsLayer = true
    titleView.layer?.backgroundColor = AppTheme.windowBackgroundNSColor.cgColor

    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 13, weight: .semibold)
    label.textColor = NSColor.labelColor.withAlphaComponent(0.72)
    label.translatesAutoresizingMaskIntoConstraints = false
    titleView.addSubview(label)

    NSLayoutConstraint.activate([
        label.leadingAnchor.constraint(equalTo: titleView.leadingAnchor, constant: 2),
        label.centerYAnchor.constraint(equalTo: titleView.centerYAnchor)
    ])

    let controller = NSTitlebarAccessoryViewController()
    controller.view = titleView
    controller.layoutAttribute = .left
    window.addTitlebarAccessoryViewController(controller)
}
