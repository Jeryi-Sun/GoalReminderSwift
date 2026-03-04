import Foundation

actor AppDataStore {
    private static let minIntervalMinutes = 5.0 / 60.0
    private static let minAdaptiveStepMinutes = 5.0 / 60.0
    private static let minPopupOverlayOpacity = 0.15
    private static let maxHistoryCount = 500

    private static let dailyTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dailyTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let dailyUpdatedAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

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
        self.state.minIntervalMinutes = min(
            max(self.state.minIntervalMinutes, Self.minIntervalMinutes),
            self.state.intervalMinutes
        )
        self.state.maxIntervalMinutes = max(self.state.maxIntervalMinutes, self.state.intervalMinutes)
        self.state.adaptiveInProgressStepMinutes = max(
            self.state.adaptiveInProgressStepMinutes,
            Self.minAdaptiveStepMinutes
        )
        self.state.adaptiveStartNowStepMinutes = max(
            self.state.adaptiveStartNowStepMinutes,
            Self.minAdaptiveStepMinutes
        )
        self.state.popupOverlayOpacity = Self.clampedPopupOverlayOpacity(self.state.popupOverlayOpacity)
    }

    func dataFilePath() -> String {
        fileURL.path
    }

    func dailyMarkdownRootPath() -> String {
        state.dailyMarkdownRootPath
    }

    func setDailyMarkdownRootPath(_ path: String) throws {
        let normalizedPath = Self.normalizedDailyMarkdownRootPath(path)
        guard !normalizedPath.isEmpty else {
            throw AppError.invalidDailyLogPath
        }
        state.dailyMarkdownRootPath = normalizedPath
        try persist()
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
        state.maxIntervalMinutes = max(state.maxIntervalMinutes, state.intervalMinutes)
        try persist()
    }

    func setReminderPolicy(
        baseMinutes: Double,
        minMinutes: Double,
        maxMinutes: Double,
        adaptiveEnabled: Bool,
        adaptiveInProgressStepMinutes: Double,
        adaptiveStartNowStepMinutes: Double,
        popupOverlayOpacity: Double
    ) throws {
        guard baseMinutes > 0 else {
            throw AppError.invalidInterval
        }
        guard minMinutes > 0 else {
            throw AppError.invalidMinInterval
        }
        let safeBase = max(baseMinutes, Self.minIntervalMinutes)
        let safeMin = max(minMinutes, Self.minIntervalMinutes)
        guard safeMin <= safeBase else {
            throw AppError.invalidMinInterval
        }
        guard maxMinutes >= safeBase else {
            throw AppError.invalidMaxInterval
        }
        guard adaptiveInProgressStepMinutes > 0 else {
            throw AppError.invalidAdaptiveStep("“正在完成”步长必须大于 0")
        }
        guard adaptiveStartNowStepMinutes > 0 else {
            throw AppError.invalidAdaptiveStep("“马上去完成”步长必须大于 0")
        }

        state.intervalMinutes = safeBase
        state.minIntervalMinutes = safeMin
        state.maxIntervalMinutes = maxMinutes
        state.adaptiveIntervalEnabled = adaptiveEnabled
        state.adaptiveInProgressStepMinutes = max(adaptiveInProgressStepMinutes, Self.minAdaptiveStepMinutes)
        state.adaptiveStartNowStepMinutes = max(adaptiveStartNowStepMinutes, Self.minAdaptiveStepMinutes)
        state.popupOverlayOpacity = Self.clampedPopupOverlayOpacity(popupOverlayOpacity)
        try persist()
    }

    func setCountdownTargetDate(_ date: Date?) throws {
        state.countdownTargetDate = date
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

    func hasGoals() -> Bool {
        !state.goals.isEmpty
    }

    func nextPendingGoal() -> Goal? {
        state.goals.first { !$0.isCompleted }
    }

    func reorderGoals(goalIDs: [UUID]) throws {
        guard goalIDs.count == state.goals.count else {
            throw AppError.goalNotFound
        }

        let goalMap = Dictionary(uniqueKeysWithValues: state.goals.map { ($0.id, $0) })
        let reordered = try goalIDs.map { id -> Goal in
            guard let goal = goalMap[id] else {
                throw AppError.goalNotFound
            }
            return goal
        }

        state.goals = reordered
        try persist()
    }

    func appendRecord(goal: Goal, status: GoalProgressStatus, startNowInput: String? = nil) throws -> ReminderRecord {
        let record = ReminderRecord(
            goalID: goal.id,
            goalTitle: goal.title,
            status: status,
            startNowInput: startNowInput
        )
        state.history.append(record)
        if state.history.count > Self.maxHistoryCount {
            state.history.removeFirst(state.history.count - Self.maxHistoryCount)
        }
        if status == .completed,
           let index = state.goals.firstIndex(where: { $0.id == goal.id }) {
            state.goals[index].isCompleted = true
        }
        try persist()
        try? syncDailyMarkdown(for: record.timestamp)
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

    private static func clampedPopupOverlayOpacity(_ value: Double) -> Double {
        min(max(value, minPopupOverlayOpacity), 1.0)
    }

    private func syncDailyMarkdown(for date: Date) throws {
        let records = dailyRecords(for: date)
        let fileURL = Self.dailyMarkdownFileURL(for: date, rootPath: state.dailyMarkdownRootPath)
        let folderURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let markdown = Self.dailyMarkdownContent(
            for: date,
            records: records,
            filePath: fileURL.path
        )
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func dailyRecords(for date: Date) -> [ReminderRecord] {
        let calendar = Calendar(identifier: .gregorian)
        return state.history
            .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private static func dailyMarkdownFileURL(for date: Date, rootPath: String) -> URL {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = String(components.year ?? 0)
        let month = String(format: "%02d", components.month ?? 0)
        let day = String(format: "%02d", components.day ?? 0)

        let rootURL = URL(fileURLWithPath: normalizedDailyMarkdownRootPath(rootPath), isDirectory: true)

        return rootURL
            .appendingPathComponent(year, isDirectory: true)
            .appendingPathComponent(month, isDirectory: true)
            .appendingPathComponent("\(day).md", isDirectory: false)
    }

    private static func normalizedDailyMarkdownRootPath(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }

        let nsPath = NSString(string: trimmed).expandingTildeInPath
        if nsPath.isEmpty {
            return ""
        }
        if nsPath.hasPrefix("/") {
            return nsPath
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(nsPath, isDirectory: true)
            .path
    }

    private static func dailyMarkdownContent(
        for date: Date,
        records: [ReminderRecord],
        filePath: String
    ) -> String {
        let inProgressRecords = records.filter { $0.status == .inProgress }
        let startNowRecords = records.filter { $0.status == .startNow }
        let completedRecords = records.filter { $0.status == .completed }

        let sections = [
            "# \(dailyTitleFormatter.string(from: date)) 目标提醒日志",
            "",
            "> 路径：`\(filePath)`",
            "> 最后更新：\(dailyUpdatedAtFormatter.string(from: Date()))",
            "",
            "## 当天统计",
            "- 正在完成次数：\(inProgressRecords.count)",
            "- 马上去完成次数：\(startNowRecords.count)",
            "- 已完成次数：\(completedRecords.count)",
            "",
            "## 正在完成的任务情况",
            markdownList(for: inProgressRecords, includeStartNowInput: false),
            "",
            "## 马上去完成",
            "- 次数：\(startNowRecords.count)",
            markdownList(for: startNowRecords, includeStartNowInput: true),
            "",
            "## 当天完成了什么任务",
            markdownList(for: completedRecords, includeStartNowInput: false),
            ""
        ]

        return sections.joined(separator: "\n")
    }

    private static func markdownList(
        for records: [ReminderRecord],
        includeStartNowInput: Bool
    ) -> String {
        guard !records.isEmpty else {
            return "- 暂无"
        }

        return records.map { record in
            let time = dailyTimeFormatter.string(from: record.timestamp)
            let shortGoalID = String(record.goalID.uuidString.prefix(6))
            let base = "- \(time) | #\(shortGoalID) | \(record.goalTitle)"

            guard includeStartNowInput,
                  let startNowInput = record.startNowInput,
                  !startNowInput.isEmpty
            else {
                return base
            }

            return "\(base) | 当时正在干：\(startNowInput)"
        }
        .joined(separator: "\n")
    }
}
