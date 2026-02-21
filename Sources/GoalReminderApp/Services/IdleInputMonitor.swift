import CoreGraphics
import Foundation

protocol IdleInputMonitoring: Sendable {
    func currentIdleSeconds() -> Double
}

struct SystemIdleInputMonitor: IdleInputMonitoring {
    private let anyInputType = CGEventType(rawValue: UInt32.max)

    func currentIdleSeconds() -> Double {
        guard let anyInputType else {
            return 0
        }

        return CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: anyInputType
        )
    }
}
