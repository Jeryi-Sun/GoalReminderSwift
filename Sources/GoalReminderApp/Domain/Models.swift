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
    let timestamp: Date

    init(
        id: UUID = UUID(),
        goalID: UUID,
        goalTitle: String,
        status: GoalProgressStatus,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.goalID = goalID
        self.goalTitle = goalTitle
        self.status = status
        self.timestamp = timestamp
    }
}

struct AppState: Codable {
    var intervalMinutes: Double
    var goals: [Goal]
    var nextGoalIndex: Int
    var history: [ReminderRecord]

    init(
        intervalMinutes: Double = 30,
        goals: [Goal] = [],
        nextGoalIndex: Int = 0,
        history: [ReminderRecord] = []
    ) {
        self.intervalMinutes = intervalMinutes
        self.goals = goals
        self.nextGoalIndex = nextGoalIndex
        self.history = history
    }
}

enum AppError: LocalizedError {
    case emptyGoal
    case invalidInterval
    case noGoalSelected
    case noGoalsAvailable
    case goalNotFound
    case pythonBridgeFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyGoal:
            return "目标内容不能为空。"
        case .invalidInterval:
            return "提醒间隔必须是大于 0 的数字。"
        case .noGoalSelected:
            return "请先选择一个目标。"
        case .noGoalsAvailable:
            return "当前没有目标，请先添加目标。"
        case .goalNotFound:
            return "目标不存在，可能已被删除。"
        case .pythonBridgeFailed(let detail):
            return "Python bridge 执行失败：\(detail)"
        }
    }
}
