import AppKit
import SwiftUI

private final class FloatingReminderPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class ReminderPopupManager {
    private var window: NSWindow?
    private var keyMonitor: Any?
    private var previousFrontmostApp: NSRunningApplication?

    var isPresenting: Bool {
        window != nil
    }

    func present(
        goal: Goal,
        countdownText: String?,
        overlayOpacity: Double,
        onSelect: @escaping (GoalProgressStatus) -> Void
    ) -> Bool {
        guard window == nil else {
            return false
        }

        previousFrontmostApp = NSWorkspace.shared.frontmostApplication

        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let rootView = ReminderPopupView(
            goalTitle: goal.title,
            countdownText: countdownText,
            overlayOpacity: overlayOpacity
        ) { [weak self] status in
            onSelect(status)
            self?.dismiss()
        }
        let hosting = NSHostingView(rootView: rootView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor

        let win = FloatingReminderPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.contentView = hosting
        win.isFloatingPanel = true
        win.hidesOnDeactivate = false
        win.becomesKeyOnlyIfNeeded = false
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isReleasedWhenClosed = false
        win.orderFrontRegardless()
        win.makeKey()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }

            switch event.charactersIgnoringModifiers {
            case "1":
                onSelect(.completed)
                self.dismiss()
                return nil
            case "2":
                onSelect(.inProgress)
                self.dismiss()
                return nil
            case "3":
                onSelect(.startNow)
                self.dismiss()
                return nil
            default:
                return event
            }
        }

        self.window = win
        return true
    }

    func dismiss() {
        let appToRestore = previousFrontmostApp
        previousFrontmostApp = nil

        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        window?.orderOut(nil)
        window = nil

        guard let appToRestore else {
            return
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        guard appToRestore.processIdentifier != currentPID else {
            return
        }

        // Restore the app the user was using before the full-screen reminder took focus.
        DispatchQueue.main.async {
            guard !appToRestore.isTerminated else {
                return
            }
            _ = appToRestore.activate(options: [.activateIgnoringOtherApps])
        }
    }
}
