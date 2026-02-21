import SwiftUI

@main
struct GoalReminderAppEntry: App {
    @StateObject private var viewModel: ReminderViewModel

    init() {
        let store = AppDataStore()
        let modelEngine = GoalInsightEngine()
        let bridge = PythonBridgeService()
        _viewModel = StateObject(
            wrappedValue: ReminderViewModel(
                store: store,
                insightEngine: modelEngine,
                pythonBridge: bridge
            )
        )
    }

    var body: some Scene {
        WindowGroup("目标提醒器") {
            ContentView(viewModel: viewModel)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
