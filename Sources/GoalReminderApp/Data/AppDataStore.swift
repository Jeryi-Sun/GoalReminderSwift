import Foundation

actor AppDataStore {
    private static let minIntervalMinutes = 5.0 / 60.0
    private static let maxHistoryCount = 500

    private let fileURL: URL
    private var state: AppState

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folderURL = base.appendingPathComponent("GoalReminderSwift", isDirectory: true)
        try? fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        self.fileURL = folderURL.appendingPathComponent("state.json")
        self.state = Self.loadState(from: fileURL) ?? AppState()
        self.state.intervalMinutes = max(self.state.intervalMinutes, Self.minIntervalMinutes)
    }

    func dataFilePath() -> String {
        fileURL.path
    }

    func snapshot() -> AppState {
        state
    }

    func intervalMinutes() -> Double {
        state.intervalMinutes
    }

    func setInterval(minutes: Double) throws {
        guard minutes > 0 else {
            throw AppError.invalidInterval
        }
        state.intervalMinutes = max(minutes, Self.minIntervalMinutes)
        try persist()
    }

    func addGoal(title: String) throws -> Goal {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppError.emptyGoal
        }

        let goal = Goal(title: trimmed)
        state.goals.append(goal)
        try persist()
        return goal
    }

    func removeGoal(id: UUID) throws -> Bool {
        let before = state.goals.count
        state.goals.removeAll { $0.id == id }
        let removed = state.goals.count != before

        guard removed else {
            return false
        }

        if state.goals.isEmpty {
            state.nextGoalIndex = 0
        } else {
            state.nextGoalIndex = state.nextGoalIndex % state.goals.count
        }

        try persist()
        return true
    }

    func goal(id: UUID) -> Goal? {
        state.goals.first { $0.id == id }
    }

    func rotateNextGoal() throws -> Goal? {
        guard !state.goals.isEmpty else {
            return nil
        }
        let idx = state.nextGoalIndex % state.goals.count
        let goal = state.goals[idx]
        state.nextGoalIndex = (idx + 1) % state.goals.count
        try persist()
        return goal
    }

    func appendRecord(goal: Goal, status: GoalProgressStatus) throws -> ReminderRecord {
        let record = ReminderRecord(goalID: goal.id, goalTitle: goal.title, status: status)
        state.history.append(record)
        if state.history.count > Self.maxHistoryCount {
            state.history.removeFirst(state.history.count - Self.maxHistoryCount)
        }
        try persist()
        return record
    }

    private func persist() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func loadState(from url: URL) -> AppState? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AppState.self, from: data)
    }
}
