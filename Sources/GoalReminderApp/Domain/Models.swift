import Foundation

struct Goal: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    let createdAt: Date

    init(id: UUID = UUID(), title: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }

    var shortID: String {
        String(id.uuidString.prefix(6))
    }
}

enum GoalProgressStatus: String, Codable, CaseIterable, Identifiable {
    case completed = "已完成"
    case inProgress = "正在完成"
    case startNow = "马上去完成"

    var id: String { rawValue }

    var buttonTitle: String {
        switch self {
        case .completed:
            return "1 已完成"
        case .inProgress:
            return "2 正在完成"
        case .startNow:
            return "3 马上去完成"
        }
    }
}

struct ReminderRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let goalID: UUID
    let goalTitle: String
    let status: GoalProgressStatus
    let startNowInput: String?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        goalID: UUID,
        goalTitle: String,
        status: GoalProgressStatus,
        startNowInput: String? = nil,
        timestamp: Date = Date()
    ) {
        let trimmedInput = startNowInput?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.goalID = goalID
        self.goalTitle = goalTitle
        self.status = status
        self.startNowInput = trimmedInput?.isEmpty == false ? trimmedInput : nil
        self.timestamp = timestamp
    }
}

struct AppState: Codable {
    var intervalMinutes: Double
    var minIntervalMinutes: Double
    var maxIntervalMinutes: Double
    var adaptiveIntervalEnabled: Bool
    var adaptiveInProgressStepMinutes: Double
    var adaptiveStartNowStepMinutes: Double
    var popupOverlayOpacity: Double
    var countdownTargetDate: Date?
    var goals: [Goal]
    var nextGoalIndex: Int
    var history: [ReminderRecord]

    init(
        intervalMinutes: Double = 30,
        minIntervalMinutes: Double = 5,
        maxIntervalMinutes: Double = 60,
        adaptiveIntervalEnabled: Bool = false,
        adaptiveInProgressStepMinutes: Double = 5,
        adaptiveStartNowStepMinutes: Double = 5,
        popupOverlayOpacity: Double = 0.88,
        countdownTargetDate: Date? = nil,
        goals: [Goal] = [],
        nextGoalIndex: Int = 0,
        history: [ReminderRecord] = []
    ) {
        self.intervalMinutes = intervalMinutes
        self.minIntervalMinutes = max(5.0 / 60.0, min(minIntervalMinutes, intervalMinutes))
        self.maxIntervalMinutes = max(maxIntervalMinutes, intervalMinutes)
        self.adaptiveIntervalEnabled = adaptiveIntervalEnabled
        self.adaptiveInProgressStepMinutes = max(5.0 / 60.0, adaptiveInProgressStepMinutes)
        self.adaptiveStartNowStepMinutes = max(5.0 / 60.0, adaptiveStartNowStepMinutes)
        self.popupOverlayOpacity = min(max(popupOverlayOpacity, 0.15), 1.0)
        self.countdownTargetDate = countdownTargetDate
        self.goals = goals
        self.nextGoalIndex = nextGoalIndex
        self.history = history
    }

    private enum CodingKeys: String, CodingKey {
        case intervalMinutes
        case minIntervalMinutes
        case maxIntervalMinutes
        case adaptiveIntervalEnabled
        case adaptiveInProgressStepMinutes
        case adaptiveStartNowStepMinutes
        case popupOverlayOpacity
        case countdownTargetDate
        case goals
        case nextGoalIndex
        case history
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let interval = try container.decodeIfPresent(Double.self, forKey: .intervalMinutes) ?? 30
        let maxInterval = try container.decodeIfPresent(Double.self, forKey: .maxIntervalMinutes) ?? max(60, interval)
        let minInterval = try container.decodeIfPresent(Double.self, forKey: .minIntervalMinutes) ?? min(5, interval)
        let defaultAdaptiveStep = max(interval * 0.15, 0.5)
        intervalMinutes = interval
        minIntervalMinutes = max(5.0 / 60.0, min(minInterval, interval))
        maxIntervalMinutes = max(maxInterval, interval)
        adaptiveIntervalEnabled = try container.decodeIfPresent(Bool.self, forKey: .adaptiveIntervalEnabled) ?? false
        adaptiveInProgressStepMinutes = max(
            5.0 / 60.0,
            try container.decodeIfPresent(Double.self, forKey: .adaptiveInProgressStepMinutes) ?? defaultAdaptiveStep
        )
        adaptiveStartNowStepMinutes = max(
            5.0 / 60.0,
            try container.decodeIfPresent(Double.self, forKey: .adaptiveStartNowStepMinutes) ?? defaultAdaptiveStep
        )
        let decodedOpacity = try container.decodeIfPresent(Double.self, forKey: .popupOverlayOpacity) ?? 0.88
        popupOverlayOpacity = min(max(decodedOpacity, 0.15), 1.0)
        countdownTargetDate = try container.decodeIfPresent(Date.self, forKey: .countdownTargetDate)
        goals = try container.decodeIfPresent([Goal].self, forKey: .goals) ?? []
        nextGoalIndex = try container.decodeIfPresent(Int.self, forKey: .nextGoalIndex) ?? 0
        history = try container.decodeIfPresent([ReminderRecord].self, forKey: .history) ?? []
    }
}

struct MobilePushConfig: Codable, Sendable {
    var enabled: Bool
    var idleThresholdMinutes: Double
    var serverChanSendKey: String
    var workTimeEnabled: Bool
    var workStartHHmm: String
    var workEndHHmm: String
    var alertTitle: String
    var alertBody: String

    init(
        enabled: Bool = false,
        idleThresholdMinutes: Double = 20,
        serverChanSendKey: String = "",
        workTimeEnabled: Bool = false,
        workStartHHmm: String = "09:00",
        workEndHHmm: String = "18:00",
        alertTitle: String = "目标提醒器",
        alertBody: String = "你已经 20 分钟没有操作电脑，是否偏离目标了？"
    ) {
        self.enabled = enabled
        self.idleThresholdMinutes = idleThresholdMinutes
        self.serverChanSendKey = serverChanSendKey
        self.workTimeEnabled = workTimeEnabled
        self.workStartHHmm = workStartHHmm
        self.workEndHHmm = workEndHHmm
        self.alertTitle = alertTitle
        self.alertBody = alertBody
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case idleThresholdMinutes
        case serverChanSendKey
        case workTimeEnabled
        case workStartHHmm
        case workEndHHmm
        case alertTitle
        case alertBody
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case sendKey
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)

        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        idleThresholdMinutes = try container.decodeIfPresent(Double.self, forKey: .idleThresholdMinutes) ?? 20
        serverChanSendKey = try container.decodeIfPresent(String.self, forKey: .serverChanSendKey)
            ?? (try legacy.decodeIfPresent(String.self, forKey: .sendKey) ?? "")
        workTimeEnabled = try container.decodeIfPresent(Bool.self, forKey: .workTimeEnabled) ?? false
        workStartHHmm = try container.decodeIfPresent(String.self, forKey: .workStartHHmm) ?? "09:00"
        workEndHHmm = try container.decodeIfPresent(String.self, forKey: .workEndHHmm) ?? "18:00"
        alertTitle = try container.decodeIfPresent(String.self, forKey: .alertTitle) ?? "目标提醒器"
        alertBody = try container.decodeIfPresent(String.self, forKey: .alertBody) ?? "你已经 20 分钟没有操作电脑，是否偏离目标了？"
    }
}

enum AppError: LocalizedError {
    case emptyGoal
    case invalidInterval
    case invalidMinInterval
    case noGoalSelected
    case noGoalsAvailable
    case goalNotFound
    case pythonBridgeFailed(String)
    case invalidMaxInterval
    case invalidAdaptiveStep(String)
    case invalidServerChanConfig(String)
    case serverChanSendFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyGoal:
            return "目标内容不能为空。"
        case .invalidInterval:
            return "提醒间隔必须是大于 0 的数字。"
        case .invalidMinInterval:
            return "最小提醒间隔必须大于 0，且不能大于基础间隔。"
        case .noGoalSelected:
            return "请先选择一个目标。"
        case .noGoalsAvailable:
            return "当前没有目标，请先添加目标。"
        case .goalNotFound:
            return "目标不存在，可能已被删除。"
        case .pythonBridgeFailed(let detail):
            return "Python bridge 执行失败：\(detail)"
        case .invalidMaxInterval:
            return "最大提醒间隔必须大于或等于基础间隔。"
        case .invalidAdaptiveStep(let detail):
            return "智能步长配置无效：\(detail)"
        case .invalidServerChanConfig(let detail):
            return "Server酱 配置无效：\(detail)"
        case .serverChanSendFailed(let detail):
            return "Server酱 发送失败：\(detail)"
        }
    }
}
