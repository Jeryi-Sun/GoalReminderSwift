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
    @Published var minIntervalText = "5.00"
    @Published var maxIntervalText = "60.00"
    @Published var adaptiveIntervalEnabled = false
    @Published var adaptiveInProgressStepText = "5.00"
    @Published var adaptiveStartNowStepText = "5.00"
    @Published var popupOpacityPercent = 88.0
    @Published var effectiveIntervalText = "当前有效间隔: --"
    @Published var nextReminderText = "下次提醒: --"
    @Published var statusText = "状态: 就绪"
    @Published var dataPathText = ""

    @Published var mobilePushEnabled = false
    @Published var mobileIdleThresholdText = "20"
    @Published var mobileWorkTimeEnabled = false
    @Published var mobileWorkStartText = "09:00"
    @Published var mobileWorkEndText = "18:00"
    @Published var serverChanSendKey = ""
    @Published var mobileAlertTitle = "目标提醒器"
    @Published var mobileAlertBody = "你已经 20 分钟没有操作电脑，是否偏离目标了？"
    @Published var mobileConfigPathText = "微信推送配置: --"
    @Published var currentIdleStateText = "当前空闲: --"
    @Published var countdownEnabled = false
    @Published var countdownTargetDate = Date().addingTimeInterval(24 * 60 * 60)
    @Published var countdownCompactText = "倒计时: 未设置"

    @Published var showingHelpSheet = false
    @Published var alertItem: AlertItem?

    private let store: AppDataStore
    private let popupManager: ReminderPopupManager
    private let insightEngine: GoalInsightProviding
    private let pythonBridge: PythonBridgeProviding
    private let mobilePushStore: MobilePushConfigStore
    private let mobilePushSender: MobilePushSending
    private let idleMonitor: IdleInputMonitoring

    private var schedulerTask: Task<Void, Never>?
    private var idleMonitorTask: Task<Void, Never>?
    private var countdownTickerTask: Task<Void, Never>?
    private var hasStarted = false
    private var popupLocked = false
    private var idlePushSentForCurrentIdlePeriod = false
    private var baseIntervalMinutes = 30.0
    private var minIntervalMinutes = 5.0
    private var maxIntervalMinutes = 60.0
    private var adaptivePolicyEnabled = false
    private var adaptiveInProgressStepMinutes = 5.0
    private var adaptiveStartNowStepMinutes = 5.0
    private var popupOverlayOpacity = 0.88
    private var effectiveIntervalMinutes = 30.0
    private var consecutiveInProgressCount = 0
    private var consecutiveStartNowCount = 0

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
        pythonBridge: PythonBridgeProviding = PythonBridgeService(),
        mobilePushStore: MobilePushConfigStore = MobilePushConfigStore(),
        mobilePushSender: MobilePushSending = ServerChanPushService(),
        idleMonitor: IdleInputMonitoring = SystemIdleInputMonitor()
    ) {
        self.store = store
        self.popupManager = popupManager
        self.insightEngine = insightEngine
        self.pythonBridge = pythonBridge
        self.mobilePushStore = mobilePushStore
        self.mobilePushSender = mobilePushSender
        self.idleMonitor = idleMonitor
    }

    deinit {
        schedulerTask?.cancel()
        idleMonitorTask?.cancel()
        countdownTickerTask?.cancel()
    }

    func onAppear() {
        guard !hasStarted else {
            return
        }
        hasStarted = true

        Task { @MainActor in
            await reloadState(preserveSelection: nil, keepCurrentIntervalInput: false)
            await loadMobilePushConfig()
            restartScheduler()
            restartIdleWatcher()
            restartCountdownTicker()
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
        let baseRaw = intervalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let minRaw = minIntervalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxRaw = maxIntervalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let inProgressStepRaw = adaptiveInProgressStepText.trimmingCharacters(in: .whitespacesAndNewlines)
        let startNowStepRaw = adaptiveStartNowStepText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let baseMinutes = Double(baseRaw), baseMinutes > 0 else {
            handleError(AppError.invalidInterval, title: "设置失败")
            return
        }
        guard let minMinutes = Double(minRaw), minMinutes > 0 else {
            handleError(AppError.invalidMinInterval, title: "设置失败")
            return
        }
        guard let maxMinutes = Double(maxRaw), maxMinutes > 0 else {
            handleError(AppError.invalidMaxInterval, title: "设置失败")
            return
        }
        guard let inProgressStep = Double(inProgressStepRaw), inProgressStep > 0 else {
            handleError(AppError.invalidAdaptiveStep("“正在完成”步长必须大于 0"), title: "设置失败")
            return
        }
        guard let startNowStep = Double(startNowStepRaw), startNowStep > 0 else {
            handleError(AppError.invalidAdaptiveStep("“马上去完成”步长必须大于 0"), title: "设置失败")
            return
        }
        guard minMinutes <= baseMinutes else {
            handleError(AppError.invalidMinInterval, title: "设置失败")
            return
        }
        guard maxMinutes >= baseMinutes else {
            handleError(AppError.invalidMaxInterval, title: "设置失败")
            return
        }

        Task { @MainActor in
            do {
                let popupOpacity = Self.clampedPopupOverlayOpacity(popupOpacityPercent / 100.0)
                try await store.setReminderPolicy(
                    baseMinutes: baseMinutes,
                    minMinutes: minMinutes,
                    maxMinutes: maxMinutes,
                    adaptiveEnabled: adaptiveIntervalEnabled,
                    adaptiveInProgressStepMinutes: inProgressStep,
                    adaptiveStartNowStepMinutes: startNowStep,
                    popupOverlayOpacity: popupOpacity
                )
                await reloadState(preserveSelection: selectedGoalID, keepCurrentIntervalInput: false)
                resetAdaptiveRuntime()
                restartScheduler()
                setStatus(
                    "提醒策略已更新：最小 \(Self.formatNumber(minIntervalMinutes)) / 基础 \(Self.formatNumber(baseIntervalMinutes)) / 最大 \(Self.formatNumber(maxIntervalMinutes)) 分钟；步长(进行中+\(Self.formatNumber(adaptiveInProgressStepMinutes))、马上去完成-\(Self.formatNumber(adaptiveStartNowStepMinutes)))；弹窗透明度 \(Int((popupOverlayOpacity * 100).rounded()))%。"
                )
            } catch {
                handleError(error, title: "设置失败")
            }
        }
    }

    func saveMobilePushConfig() {
        let config = currentMobilePushConfig()

        if config.enabled, config.serverChanSendKey.isEmpty {
            handleError(AppError.invalidServerChanConfig("启用推送时必须填写 SendKey"), title: "保存手机推送配置失败")
            return
        }
        if config.workTimeEnabled,
           !Self.isValidHHmm(config.workStartHHmm) || !Self.isValidHHmm(config.workEndHHmm)
        {
            handleError(AppError.invalidServerChanConfig("工作时段格式应为 HH:mm"), title: "保存手机推送配置失败")
            return
        }

        Task { @MainActor in
            do {
                try await mobilePushStore.save(config)
                await loadMobilePushConfig()
                restartIdleWatcher()
                setStatus("手机推送配置已保存。")
            } catch {
                handleError(error, title: "保存手机推送配置失败")
            }
        }
    }

    func saveCountdown() {
        let targetDate = countdownEnabled ? countdownTargetDate : nil

        Task { @MainActor in
            do {
                try await store.setCountdownTargetDate(targetDate)
                await reloadState(preserveSelection: selectedGoalID, keepCurrentIntervalInput: true)
                if let targetDate {
                    setStatus("倒计时已保存：截止 \(Self.historyFormatter.string(from: targetDate))")
                } else {
                    setStatus("倒计时已关闭。")
                }
            } catch {
                handleError(error, title: "保存倒计时失败")
            }
        }
    }

    func clearCountdown() {
        countdownEnabled = false
        updateCountdownCompactText()
        Task { @MainActor in
            do {
                try await store.setCountdownTargetDate(nil)
                await reloadState(preserveSelection: selectedGoalID, keepCurrentIntervalInput: true)
                setStatus("倒计时已清除。")
            } catch {
                handleError(error, title: "清除倒计时失败")
            }
        }
    }

    func sendTestMobilePush() {
        let config = currentMobilePushConfig()

        Task { @MainActor in
            do {
                try await mobilePushSender.sendTestAlert(config: config)
                setStatus("已发送测试微信提醒。")
            } catch {
                handleError(error, title: "测试推送失败")
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
                let intervalMinutes = currentSchedulerIntervalMinutes()
                let intervalSeconds = max(intervalMinutes * 60.0, Self.minIntervalSeconds)
                let nextDate = Date().addingTimeInterval(intervalSeconds)
                nextReminderText = "下次提醒: \(Self.timeFormatter.string(from: nextDate))"
                effectiveIntervalText = "当前有效间隔: \(Self.formatNumber(intervalMinutes)) 分钟"

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

    private func restartIdleWatcher() {
        idleMonitorTask?.cancel()
        idleMonitorTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                let config = currentMobilePushConfig()

                if config.enabled {
                    if config.workTimeEnabled, !isWithinWorkTime(config: config) {
                        currentIdleStateText = "当前空闲: 工作时段外（\(config.workStartHHmm)-\(config.workEndHHmm)）"
                        idlePushSentForCurrentIdlePeriod = false
                    } else {
                        let idleSeconds = idleMonitor.currentIdleSeconds()
                        currentIdleStateText = "当前空闲: \(Int(idleSeconds)) 秒"

                        if idleSeconds < 2 {
                            idlePushSentForCurrentIdlePeriod = false
                        }

                        let thresholdSeconds = max(config.idleThresholdMinutes * 60.0, 60)
                        if idleSeconds >= thresholdSeconds && !idlePushSentForCurrentIdlePeriod {
                            idlePushSentForCurrentIdlePeriod = true
                            await sendIdleAlertToMobile(config: config, idleSeconds: idleSeconds)
                        }
                    }
                } else {
                    currentIdleStateText = "当前空闲: 未启用手机空闲推送"
                    idlePushSentForCurrentIdlePeriod = false
                }

                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                } catch {
                    break
                }
            }
        }
    }

    private func sendIdleAlertToMobile(config: MobilePushConfig, idleSeconds: Double) async {
        do {
            try await mobilePushSender.sendIdleAlert(config: config, idleSeconds: idleSeconds)
            setStatus("已发送微信空闲提醒（\(Int(idleSeconds / 60)) 分钟未操作）")
        } catch {
            handleError(error, title: "手机空闲推送失败")
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
        let shown = popupManager.present(
            goal: goal,
            countdownText: popupCountdownText(),
            overlayOpacity: popupOverlayOpacity
        ) { [weak self] status in
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
            let policyNote = updateAdaptiveInterval(after: status)
            if let policyNote {
                setStatus("已记录：\(record.status.rawValue)（\(goal.title)）；\(policyNote)")
            } else {
                setStatus("已记录：\(record.status.rawValue)（\(goal.title)）")
            }
        } catch {
            handleError(error, title: "记录失败")
        }
    }

    private func loadMobilePushConfig() async {
        let config = await mobilePushStore.load()
        let configPath = await mobilePushStore.configPath()

        mobilePushEnabled = config.enabled
        mobileIdleThresholdText = Self.formatNumber(config.idleThresholdMinutes)
        mobileWorkTimeEnabled = config.workTimeEnabled
        mobileWorkStartText = config.workStartHHmm
        mobileWorkEndText = config.workEndHHmm
        serverChanSendKey = config.serverChanSendKey
        mobileAlertTitle = config.alertTitle
        mobileAlertBody = config.alertBody
        mobileConfigPathText = "微信推送配置: \(configPath)"
    }

    private func currentMobilePushConfig() -> MobilePushConfig {
        let threshold = max(Double(mobileIdleThresholdText) ?? 20, 1)
        return MobilePushConfig(
            enabled: mobilePushEnabled,
            idleThresholdMinutes: threshold,
            serverChanSendKey: serverChanSendKey.trimmingCharacters(in: .whitespacesAndNewlines),
            workTimeEnabled: mobileWorkTimeEnabled,
            workStartHHmm: Self.normalizedHHmm(mobileWorkStartText, fallback: "09:00"),
            workEndHHmm: Self.normalizedHHmm(mobileWorkEndText, fallback: "18:00"),
            alertTitle: mobileAlertTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "目标提醒器"
                : mobileAlertTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            alertBody: mobileAlertBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "你已经 20 分钟没有操作电脑，是否偏离目标了？"
                : mobileAlertBody.trimmingCharacters(in: .whitespacesAndNewlines)
        )
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

        baseIntervalMinutes = snapshot.intervalMinutes
        minIntervalMinutes = min(snapshot.minIntervalMinutes, baseIntervalMinutes)
        maxIntervalMinutes = max(snapshot.maxIntervalMinutes, baseIntervalMinutes)
        adaptivePolicyEnabled = snapshot.adaptiveIntervalEnabled
        adaptiveInProgressStepMinutes = snapshot.adaptiveInProgressStepMinutes
        adaptiveStartNowStepMinutes = snapshot.adaptiveStartNowStepMinutes
        popupOverlayOpacity = Self.clampedPopupOverlayOpacity(snapshot.popupOverlayOpacity)
        if !keepCurrentIntervalInput {
            intervalText = Self.formatNumber(baseIntervalMinutes)
            minIntervalText = Self.formatNumber(minIntervalMinutes)
            maxIntervalText = Self.formatNumber(maxIntervalMinutes)
            adaptiveIntervalEnabled = adaptivePolicyEnabled
            adaptiveInProgressStepText = Self.formatNumber(adaptiveInProgressStepMinutes)
            adaptiveStartNowStepText = Self.formatNumber(adaptiveStartNowStepMinutes)
            popupOpacityPercent = (popupOverlayOpacity * 100).rounded()
        }
        if !adaptivePolicyEnabled {
            effectiveIntervalMinutes = baseIntervalMinutes
            consecutiveInProgressCount = 0
            consecutiveStartNowCount = 0
        } else {
            effectiveIntervalMinutes = min(maxIntervalMinutes, max(effectiveIntervalMinutes, minIntervalMinutes))
        }
        effectiveIntervalText = "当前有效间隔: \(Self.formatNumber(effectiveIntervalMinutes)) 分钟"

        if let targetDate = snapshot.countdownTargetDate {
            countdownEnabled = true
            countdownTargetDate = targetDate
        } else {
            countdownEnabled = false
            countdownTargetDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(24 * 60 * 60)
        }
        updateCountdownCompactText()

        if let preserveSelection,
           goals.contains(where: { $0.id == preserveSelection }) {
            selectedGoalID = preserveSelection
        } else if let selectedGoalID,
                  !goals.contains(where: { $0.id == selectedGoalID }) {
            self.selectedGoalID = nil
        }
    }

    private func currentSchedulerIntervalMinutes() -> Double {
        if !adaptivePolicyEnabled {
            effectiveIntervalMinutes = baseIntervalMinutes
        }
        effectiveIntervalMinutes = min(maxIntervalMinutes, max(minIntervalMinutes, effectiveIntervalMinutes))
        return effectiveIntervalMinutes
    }

    private func resetAdaptiveRuntime() {
        consecutiveInProgressCount = 0
        consecutiveStartNowCount = 0
        effectiveIntervalMinutes = baseIntervalMinutes
        effectiveIntervalText = "当前有效间隔: \(Self.formatNumber(effectiveIntervalMinutes)) 分钟"
    }

    private func updateAdaptiveInterval(after status: GoalProgressStatus) -> String? {
        guard adaptivePolicyEnabled else {
            resetAdaptiveRuntime()
            return nil
        }

        switch status {
        case .inProgress:
            consecutiveInProgressCount += 1
            consecutiveStartNowCount = 0
            let oldValue = effectiveIntervalMinutes
            let step = max(adaptiveInProgressStepMinutes, Self.minIntervalSeconds / 60.0)
            effectiveIntervalMinutes = min(maxIntervalMinutes, max(minIntervalMinutes, oldValue + step))
            effectiveIntervalText = "当前有效间隔: \(Self.formatNumber(effectiveIntervalMinutes)) 分钟"

            if abs(effectiveIntervalMinutes - oldValue) < 0.001 {
                return "连续 \(consecutiveInProgressCount) 次“正在完成”，已达到最大间隔 \(Self.formatNumber(maxIntervalMinutes)) 分钟"
            }
            return "连续 \(consecutiveInProgressCount) 次“正在完成”，间隔调整为 \(Self.formatNumber(effectiveIntervalMinutes)) 分钟"
        case .startNow:
            consecutiveStartNowCount += 1
            consecutiveInProgressCount = 0
            let oldValue = effectiveIntervalMinutes
            let step = max(adaptiveStartNowStepMinutes, Self.minIntervalSeconds / 60.0)
            let targetValue = baseIntervalMinutes - (Double(consecutiveStartNowCount) * step)
            effectiveIntervalMinutes = max(minIntervalMinutes, min(maxIntervalMinutes, targetValue))
            effectiveIntervalText = "当前有效间隔: \(Self.formatNumber(effectiveIntervalMinutes)) 分钟"

            if abs(effectiveIntervalMinutes - oldValue) < 0.001 {
                return "连续 \(consecutiveStartNowCount) 次“马上去完成”，已达到最小间隔 \(Self.formatNumber(minIntervalMinutes)) 分钟"
            }
            return "连续 \(consecutiveStartNowCount) 次“马上去完成”，提醒加快到 \(Self.formatNumber(effectiveIntervalMinutes)) 分钟"
        case .completed:
            let shouldReset = consecutiveInProgressCount > 0 || abs(effectiveIntervalMinutes - baseIntervalMinutes) > 0.001
            resetAdaptiveRuntime()
            if shouldReset {
                return "状态变化，间隔恢复为基础值 \(Self.formatNumber(baseIntervalMinutes)) 分钟"
            }
            return nil
        }
    }

    private func restartCountdownTicker() {
        countdownTickerTask?.cancel()
        countdownTickerTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            updateCountdownCompactText()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    break
                }
                updateCountdownCompactText()
            }
        }
    }

    private func popupCountdownText() -> String? {
        guard let targetDate = activeCountdownTargetDate() else {
            return nil
        }
        return Self.countdownPopupText(targetDate: targetDate, now: Date())
    }

    private func activeCountdownTargetDate() -> Date? {
        countdownEnabled ? countdownTargetDate : nil
    }

    private func updateCountdownCompactText() {
        guard let targetDate = activeCountdownTargetDate() else {
            countdownCompactText = "倒计时: 未设置"
            return
        }
        countdownCompactText = Self.countdownCompactText(targetDate: targetDate, now: Date())
    }

    private func isWithinWorkTime(config: MobilePushConfig) -> Bool {
        guard config.workTimeEnabled else {
            return true
        }
        guard let start = Self.minutesFromHHmm(config.workStartHHmm),
              let end = Self.minutesFromHHmm(config.workEndHHmm)
        else {
            return true
        }

        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let nowMinutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)

        if start == end {
            return true
        }
        if start < end {
            return nowMinutes >= start && nowMinutes < end
        }
        return nowMinutes >= start || nowMinutes < end
    }

    private static func isValidHHmm(_ value: String) -> Bool {
        minutesFromHHmm(value) != nil
    }

    private static func normalizedHHmm(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minutes = minutesFromHHmm(trimmed) else {
            return fallback
        }
        let hour = minutes / 60
        let minute = minutes % 60
        return String(format: "%02d:%02d", hour, minute)
    }

    private static func minutesFromHHmm(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0 ... 23).contains(hour),
              (0 ... 59).contains(minute)
        else {
            return nil
        }
        return hour * 60 + minute
    }

    private static func formatNumber(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func clampedPopupOverlayOpacity(_ value: Double) -> Double {
        min(max(value, 0.15), 1.0)
    }

    private static func countdownCompactText(targetDate: Date, now: Date) -> String {
        let delta = targetDate.timeIntervalSince(now)
        if delta >= 0 {
            return "倒计时: 还剩 \(countdownDurationText(seconds: delta))"
        }
        return "倒计时: 已到期 \(countdownDurationText(seconds: abs(delta)))"
    }

    private static func countdownPopupText(targetDate: Date, now: Date) -> String {
        let delta = targetDate.timeIntervalSince(now)
        if delta >= 0 {
            return "倒计时：还剩 \(countdownDurationText(seconds: delta))"
        }
        return "倒计时：已到期 \(countdownDurationText(seconds: abs(delta)))"
    }

    private static func countdownDurationText(seconds: TimeInterval) -> String {
        let totalMinutes = max(Int(ceil(seconds / 60.0)), 0)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60
        return "\(days)天 \(hours)小时 \(minutes) min"
    }
}
