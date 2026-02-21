import Foundation

@MainActor
final class ReminderViewModel: ObservableObject {
    struct AlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @Published var goals: [Goal] = []
    @Published var history: [ReminderRecord] = []
    @Published var selectedGoalID: UUID?

    @Published var newGoalTitle = ""
    @Published var intervalText = "30.00"
    @Published var nextReminderText = "下次提醒: --"
    @Published var statusText = "状态: 就绪"
    @Published var dataPathText = ""

    @Published var showingHelpSheet = false
    @Published var alertItem: AlertItem?

    private let store: AppDataStore
    private let popupManager: ReminderPopupManager
    private let insightEngine: GoalInsightProviding
    private let pythonBridge: PythonBridgeProviding

    private var schedulerTask: Task<Void, Never>?
    private var hasStarted = false
    private var popupLocked = false

    private static let minIntervalSeconds = 5.0

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let historyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    init(
        store: AppDataStore,
        popupManager: ReminderPopupManager = ReminderPopupManager(),
        insightEngine: GoalInsightProviding = GoalInsightEngine(),
        pythonBridge: PythonBridgeProviding = PythonBridgeService()
    ) {
        self.store = store
        self.popupManager = popupManager
        self.insightEngine = insightEngine
        self.pythonBridge = pythonBridge
    }

    deinit {
        schedulerTask?.cancel()
    }

    func onAppear() {
        guard !hasStarted else {
            return
        }
        hasStarted = true

        Task { @MainActor in
            await reloadState(preserveSelection: nil, keepCurrentIntervalInput: false)
            restartScheduler()
            if goals.isEmpty {
                setStatus("先添加至少一个目标，然后设置提醒间隔。")
                showingHelpSheet = true
            } else {
                setStatus("应用已启动，提醒循环已开始。")
            }
        }
    }

    func openHelp() {
        showingHelpSheet = true
    }

    func addGoal() {
        let title = newGoalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { @MainActor in
            do {
                let goal = try await store.addGoal(title: title)
                newGoalTitle = ""
                await reloadState(preserveSelection: goal.id, keepCurrentIntervalInput: true)
                let score = insightEngine.scoreGoalPriority(text: goal.title)
                setStatus("已添加目标 #\(goal.shortID)（建议优先级 \(Int(score * 100))）")
            } catch {
                handleError(error, title: "添加失败")
            }
        }
    }

    func removeSelectedGoal() {
        guard let id = selectedGoalID else {
            handleError(AppError.noGoalSelected, title: "删除失败")
            return
        }

        Task { @MainActor in
            do {
                let removed = try await store.removeGoal(id: id)
                guard removed else {
                    throw AppError.goalNotFound
                }
                await reloadState(preserveSelection: nil, keepCurrentIntervalInput: true)
                setStatus("已删除目标。")
            } catch {
                handleError(error, title: "删除失败")
            }
        }
    }

    func saveInterval() {
        let raw = intervalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minutes = Double(raw), minutes > 0 else {
            handleError(AppError.invalidInterval, title: "设置失败")
            return
        }

        Task { @MainActor in
            do {
                try await store.setInterval(minutes: minutes)
                await reloadState(preserveSelection: selectedGoalID, keepCurrentIntervalInput: false)
                restartScheduler()
                setStatus("提醒间隔已更新为 \(intervalText) 分钟。")
            } catch {
                handleError(error, title: "设置失败")
            }
        }
    }

    func triggerSelectedGoalNow() {
        guard let id = selectedGoalID else {
            handleError(AppError.noGoalSelected, title: "触发失败")
            return
        }

        Task { @MainActor in
            do {
                guard let goal = await store.goal(id: id) else {
                    throw AppError.goalNotFound
                }
                presentPopup(for: goal, source: "手动提醒")
            } catch {
                handleError(error, title: "触发失败")
            }
        }
    }

    func triggerNextGoalNow() {
        Task { @MainActor in
            do {
                guard let goal = try await store.rotateNextGoal() else {
                    throw AppError.noGoalsAvailable
                }
                await reloadState(preserveSelection: goal.id, keepCurrentIntervalInput: true)
                presentPopup(for: goal, source: "手动提醒")
            } catch {
                handleError(error, title: "触发失败")
            }
        }
    }

    func refreshHistory() {
        Task { @MainActor in
            await reloadState(preserveSelection: selectedGoalID, keepCurrentIntervalInput: true)
            setStatus("记录已刷新。")
        }
    }

    func checkPythonBridge() {
        Task { @MainActor in
            do {
                let result = try await pythonBridge.runInline(code: "print('bridge_ok')")
                let text = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                setStatus("Python bridge 正常：\(text.isEmpty ? "ok" : text)")
            } catch {
                handleError(error, title: "Python bridge")
            }
        }
    }

    func historyLine(for record: ReminderRecord) -> String {
        let time = Self.historyFormatter.string(from: record.timestamp)
        let shortGoalID = String(record.goalID.uuidString.prefix(6))
        return "\(time) | #\(shortGoalID) | \(record.status.rawValue) | \(record.goalTitle)"
    }

    private func setStatus(_ text: String) {
        statusText = "状态 \(Self.timeFormatter.string(from: Date())): \(text)"
    }

    private func handleError(_ error: Error, title: String) {
        let message = error.localizedDescription
        alertItem = AlertItem(title: title, message: message)
        setStatus(message)
    }

    private func restartScheduler() {
        schedulerTask?.cancel()
        schedulerTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            while !Task.isCancelled {
                let intervalSeconds = max(await store.intervalMinutes() * 60.0, Self.minIntervalSeconds)
                let nextDate = Date().addingTimeInterval(intervalSeconds)
                nextReminderText = "下次提醒: \(Self.timeFormatter.string(from: nextDate))"

                do {
                    try await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
                } catch {
                    break
                }

                if Task.isCancelled {
                    break
                }

                await fireScheduledReminder()
            }
        }
    }

    private func fireScheduledReminder() async {
        if popupLocked || popupManager.isPresenting {
            setStatus("上一个弹窗还未处理，已跳过本次提醒。")
            return
        }

        do {
            guard let goal = try await store.rotateNextGoal() else {
                setStatus("当前没有目标，请先添加目标。")
                return
            }
            await reloadState(preserveSelection: goal.id, keepCurrentIntervalInput: true)
            presentPopup(for: goal, source: "定时提醒")
        } catch {
            handleError(error, title: "定时提醒失败")
        }
    }

    private func presentPopup(for goal: Goal, source: String) {
        if popupLocked || popupManager.isPresenting {
            setStatus("已有未处理弹窗，请先完成当前弹窗。")
            return
        }

        popupLocked = true
        let shown = popupManager.present(goal: goal) { [weak self] status in
            guard let self else {
                return
            }
            Task { @MainActor in
                await self.completePopup(goal: goal, status: status)
            }
        }

        guard shown else {
            popupLocked = false
            setStatus("弹窗显示失败，请重试。")
            return
        }

        setStatus("\(source)：\(goal.title)")
    }

    private func completePopup(goal: Goal, status: GoalProgressStatus) async {
        defer {
            popupLocked = false
        }

        do {
            let record = try await store.appendRecord(goal: goal, status: status)
            await reloadState(preserveSelection: goal.id, keepCurrentIntervalInput: true)
            setStatus("已记录：\(record.status.rawValue)（\(goal.title)）")
        } catch {
            handleError(error, title: "记录失败")
        }
    }

    private func reloadState(
        preserveSelection: UUID?,
        keepCurrentIntervalInput: Bool
    ) async {
        let snapshot = await store.snapshot()
        let path = await store.dataFilePath()

        goals = snapshot.goals
        history = Array(snapshot.history.suffix(60).reversed())
        dataPathText = "数据文件: \(path)"

        if !keepCurrentIntervalInput {
            intervalText = Self.formatInterval(snapshot.intervalMinutes)
        }

        if let preserveSelection,
           goals.contains(where: { $0.id == preserveSelection }) {
            selectedGoalID = preserveSelection
        } else if let selectedGoalID,
                  !goals.contains(where: { $0.id == selectedGoalID }) {
            self.selectedGoalID = nil
        }
    }

    private static func formatInterval(_ minutes: Double) -> String {
        String(format: "%.2f", minutes)
    }
}
