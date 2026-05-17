import AppKit
import SwiftUI

enum RigidScrollBehavior {
    static func configure(_ scrollView: NSScrollView) {
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
    }

    static func clamp(_ scrollView: NSScrollView) {
        guard let documentView = scrollView.documentView else {
            return
        }

        let clipView = scrollView.contentView
        let visibleBounds = clipView.bounds
        let documentBounds = documentView.bounds
        let maximumX = max(documentBounds.minX, documentBounds.maxX - visibleBounds.width)
        let maximumY = max(documentBounds.minY, documentBounds.maxY - visibleBounds.height)
        let clampedOrigin = NSPoint(
            x: min(max(visibleBounds.origin.x, documentBounds.minX), maximumX),
            y: min(max(visibleBounds.origin.y, documentBounds.minY), maximumY)
        )

        guard clampedOrigin != visibleBounds.origin else {
            return
        }

        clipView.scroll(to: clampedOrigin)
        scrollView.reflectScrolledClipView(clipView)
    }

    final class Controller {
        private weak var observedScrollView: NSScrollView?
        private weak var observedClipView: NSClipView?
        private var boundsObserver: NSObjectProtocol?
        private var scrollViewObservers: [NSObjectProtocol] = []
        private var isClampingScrollPosition = false

        deinit {
            detach()
        }

        func install(on scrollView: NSScrollView) {
            RigidScrollBehavior.configure(scrollView)
            clampScrollPosition(scrollView)

            let clipView = scrollView.contentView
            guard observedScrollView !== scrollView || observedClipView !== clipView else {
                return
            }

            detach()
            observedScrollView = scrollView
            observedClipView = clipView
            clipView.postsBoundsChangedNotifications = true
            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self] _ in
                self?.clampObservedScrollPosition()
            }
            installLiveScrollObservers(for: scrollView)
        }

        func detach() {
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }
            for observer in scrollViewObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            boundsObserver = nil
            scrollViewObservers = []
            observedScrollView = nil
            observedClipView = nil
        }

        private func installLiveScrollObservers(for scrollView: NSScrollView) {
            let notificationCenter = NotificationCenter.default
            scrollViewObservers = [
                notificationCenter.addObserver(
                    forName: NSScrollView.didLiveScrollNotification,
                    object: scrollView,
                    queue: .main
                ) { [weak self] _ in
                    self?.clampObservedScrollPosition()
                },
                notificationCenter.addObserver(
                    forName: NSScrollView.didEndLiveScrollNotification,
                    object: scrollView,
                    queue: .main
                ) { [weak self] _ in
                    self?.clampObservedScrollPosition()
                }
            ]
        }

        private func clampObservedScrollPosition() {
            guard !isClampingScrollPosition,
                  let scrollView = observedScrollView else {
                return
            }

            clampScrollPosition(scrollView)
        }

        private func clampScrollPosition(_ scrollView: NSScrollView) {
            guard !isClampingScrollPosition else {
                return
            }

            isClampingScrollPosition = true
            defer { isClampingScrollPosition = false }
            RigidScrollBehavior.clamp(scrollView)
        }
    }
}

extension View {
    func rigidScrollBehavior() -> some View {
        background {
            RigidScrollBehaviorObserver()
        }
    }
}

struct RigidScrollBehaviorObserver: NSViewRepresentable {
    func makeNSView(context: Context) -> ObserverView {
        ObserverView()
    }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.installIfPossible()
    }

    final class ObserverView: NSView {
        private weak var observedScrollView: NSScrollView?
        private weak var observedClipView: NSClipView?
        private var boundsObserver: NSObjectProtocol?
        private var scrollViewObservers: [NSObjectProtocol] = []
        private var isClampingScrollPosition = false

        deinit {
            removeObservers()
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            installAfterLayout()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            installAfterLayout()
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        func installIfPossible() {
            guard let scrollView = targetScrollView else {
                return
            }

            RigidScrollBehavior.configure(scrollView)
            clampScrollPosition(scrollView)

            let clipView = scrollView.contentView
            guard observedScrollView !== scrollView || observedClipView !== clipView else {
                return
            }

            removeObservers()
            observedScrollView = scrollView
            observedClipView = clipView
            clipView.postsBoundsChangedNotifications = true
            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self] _ in
                self?.clampObservedScrollPosition()
            }
            installLiveScrollObservers(for: scrollView)
        }

        private func installAfterLayout() {
            DispatchQueue.main.async { [weak self] in
                self?.installIfPossible()
            }
        }

        private func removeObservers() {
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }
            for observer in scrollViewObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            boundsObserver = nil
            scrollViewObservers = []
            observedScrollView = nil
            observedClipView = nil
        }

        private func installLiveScrollObservers(for scrollView: NSScrollView) {
            let notificationCenter = NotificationCenter.default
            scrollViewObservers = [
                notificationCenter.addObserver(
                    forName: NSScrollView.didLiveScrollNotification,
                    object: scrollView,
                    queue: .main
                ) { [weak self] _ in
                    self?.clampObservedScrollPosition()
                },
                notificationCenter.addObserver(
                    forName: NSScrollView.didEndLiveScrollNotification,
                    object: scrollView,
                    queue: .main
                ) { [weak self] _ in
                    self?.clampObservedScrollPosition()
                }
            ]
        }

        private func clampObservedScrollPosition() {
            guard !isClampingScrollPosition,
                  let scrollView = observedScrollView else {
                return
            }

            clampScrollPosition(scrollView)
        }

        private func clampScrollPosition(_ scrollView: NSScrollView) {
            guard !isClampingScrollPosition else {
                return
            }

            isClampingScrollPosition = true
            defer { isClampingScrollPosition = false }
            RigidScrollBehavior.clamp(scrollView)
        }

        private var targetScrollView: NSScrollView? {
            var candidate = superview
            while let view = candidate {
                if let scrollView = view as? NSScrollView {
                    return scrollView
                }
                if let scrollView = firstDescendantScrollView(in: view) {
                    return scrollView
                }
                candidate = view.superview
            }
            return nil
        }

        private func firstDescendantScrollView(in view: NSView) -> NSScrollView? {
            for subview in view.subviews where subview !== self {
                if let scrollView = subview as? NSScrollView {
                    return scrollView
                }
                if let scrollView = firstDescendantScrollView(in: subview) {
                    return scrollView
                }
            }
            return nil
        }
    }
}
