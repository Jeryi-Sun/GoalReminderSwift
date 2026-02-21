import AppKit
import SwiftUI

@MainActor
final class ReminderPopupManager {
    private var window: NSWindow?
    private var keyMonitor: Any?

    var isPresenting: Bool {
        window != nil
    }

    func present(goal: Goal, onSelect: @escaping (GoalProgressStatus) -> Void) -> Bool {
        guard window == nil else {
            return false
        }

        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let rootView = ReminderPopupView(goalTitle: goal.title) { [weak self] status in
            onSelect(status)
            self?.dismiss()
        }
        let hosting = NSHostingView(rootView: rootView)

        let win = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.contentView = hosting
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        win.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.93, blue: 0.88, alpha: 1)
        win.isOpaque = true
        win.hasShadow = false
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

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
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        window?.orderOut(nil)
        window = nil
    }
}
