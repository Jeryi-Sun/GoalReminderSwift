import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ReminderViewModel

    var body: some View {
        VStack(spacing: 12) {
            header
            quickStart
            bodySection
            statusBar
        }
        .padding(18)
        .frame(minWidth: 1080, minHeight: 760)
        .background(Color(hex: "F6F2EE"))
        .onAppear {
            viewModel.onAppear()
        }
        .sheet(isPresented: $viewModel.showingHelpSheet) {
            HelpSheetView()
        }
        .alert(item: $viewModel.alertItem) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("好的"))
            )
        }
    }

    private var header: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("目标提醒器")
                        .font(.arial(size: 30, weight: .bold))
                        .foregroundStyle(Color(hex: "1F1F1F"))

                    Text("SwiftUI 原生桌面版：目标管理 + 定时全屏提醒")
                        .font(.arial(size: 13))
                        .foregroundStyle(Color(hex: "666666"))
                }

                Spacer()

                HStack(spacing: 10) {
                    Button("Python Bridge 检查") {
                        viewModel.checkPythonBridge()
                    }
                    .buttonStyle(.plain)
                    .font(.arial(size: 12, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(hex: "B4DDF4"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button("使用说明") {
                        viewModel.openHelp()
                    }
                    .buttonStyle(.plain)
                    .font(.arial(size: 12, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(hex: "F4E4B0"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private var quickStart: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text("快速开始（30秒）")
                    .font(.arial(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "1F1F1F"))
                Text("1. 左侧输入目标并点击添加")
                    .font(.arial(size: 12))
                Text("2. 右侧设置基础间隔 + 最大间隔，开启智能调节")
                    .font(.arial(size: 12))
                Text("3. 如需手机告警，填写 Server酱 SendKey，并可限定工作时段")
                    .font(.arial(size: 12))
                Text("4. 等待全屏弹窗，选择 已完成 / 正在完成 / 马上去完成")
                    .font(.arial(size: 12))
            }
            .foregroundStyle(Color(hex: "1F1F1F"))
        }
    }

    private var bodySection: some View {
        HStack(alignment: .top, spacing: 12) {
            goalPanel
            settingsPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var goalPanel: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("目标管理")
                    .font(.arial(size: 20, weight: .bold))

                Text("步骤1：输入目标")
                    .font(.arial(size: 12, weight: .bold))

                HStack(spacing: 8) {
                    TextField("例如：完成今天论文图表初稿", text: $viewModel.newGoalTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.arial(size: 13))

                    Button("添加目标") {
                        viewModel.addGoal()
                    }
                    .buttonStyle(.plain)
                    .font(.arial(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "579FCA"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Text("步骤2：选择目标并操作")
                    .font(.arial(size: 12, weight: .bold))

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "FCFCFC"))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(hex: "E7D8CC"), lineWidth: 1)
                        }

                    if viewModel.goals.isEmpty {
                        Text("暂无目标，请先添加。")
                            .font(.arial(size: 13))
                            .foregroundStyle(Color(hex: "666666"))
                    } else {
                        List(viewModel.goals, selection: $viewModel.selectedGoalID) { goal in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal.title)
                                    .font(.arial(size: 13, weight: .bold))
                                Text("#\(goal.shortID)")
                                    .font(.arial(size: 11))
                                    .foregroundStyle(Color(hex: "666666"))
                            }
                            .padding(.vertical, 4)
                            .tag(goal.id)
                        }
                        .listStyle(.inset)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    }
                }
                .frame(maxHeight: .infinity)

                HStack(spacing: 8) {
                    Button("删除所选") {
                        viewModel.removeSelectedGoal()
                    }
                    .buttonStyle(.plain)
                    .font(.arial(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "DE7D82"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button("立即提醒所选") {
                        viewModel.triggerSelectedGoalNow()
                    }
                    .buttonStyle(.plain)
                    .font(.arial(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "B4DDF4"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button("立即提醒下一个目标") {
                    viewModel.triggerNextGoalNow()
                }
                .buttonStyle(.plain)
                .font(.arial(size: 12, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color(hex: "F7DC7C"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .foregroundStyle(Color(hex: "1F1F1F"))
        }
        .frame(maxWidth: .infinity)
    }

    private var settingsPanel: some View {
        Card {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("设置与记录")
                        .font(.arial(size: 20, weight: .bold))

                    Text("步骤3：设置提醒策略（分钟）")
                        .font(.arial(size: 12, weight: .bold))

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("基础间隔")
                                .font(.arial(size: 11))
                            TextField("30", text: $viewModel.intervalText)
                                .textFieldStyle(.roundedBorder)
                                .font(.arial(size: 13))
                                .frame(width: 90)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("最大间隔")
                                .font(.arial(size: 11))
                            TextField("60", text: $viewModel.maxIntervalText)
                                .textFieldStyle(.roundedBorder)
                                .font(.arial(size: 13))
                                .frame(width: 90)
                        }

                        Button("保存策略") {
                            viewModel.saveInterval()
                        }
                        .buttonStyle(.plain)
                        .font(.arial(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(hex: "579FCA"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Spacer()
                    }

                    Toggle("启用智能间隔（连续“正在完成”会逐步拉长提醒）", isOn: $viewModel.adaptiveIntervalEnabled)
                        .font(.arial(size: 12))
                        .toggleStyle(.switch)

                    Text(viewModel.effectiveIntervalText)
                        .font(.arial(size: 11))
                        .foregroundStyle(Color(hex: "666666"))

                    Text(viewModel.dataPathText)
                        .font(.arial(size: 10))
                        .foregroundStyle(Color(hex: "666666"))

                    Divider()

                    Text("手机端告警（Server酱 微信推送）")
                        .font(.arial(size: 14, weight: .bold))

                    Toggle("启用空闲推送到微信", isOn: $viewModel.mobilePushEnabled)
                        .font(.arial(size: 12, weight: .bold))
                        .toggleStyle(.switch)

                    HStack(spacing: 8) {
                        Text("空闲阈值(分钟)")
                            .font(.arial(size: 12))
                        TextField("20", text: $viewModel.mobileIdleThresholdText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }

                    Toggle("只在工作时段内发送空闲推送", isOn: $viewModel.mobileWorkTimeEnabled)
                        .font(.arial(size: 12))
                        .toggleStyle(.switch)

                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("工作开始")
                                .font(.arial(size: 11))
                            TextField("09:00", text: $viewModel.mobileWorkStartText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("工作结束")
                                .font(.arial(size: 11))
                            TextField("18:00", text: $viewModel.mobileWorkEndText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                        }
                        Spacer()
                    }

                    TextField("Server酱 SendKey（SCTxxxxxxxx）", text: $viewModel.serverChanSendKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.arial(size: 12))

                    Text("前往 https://sct.ftqq.com 获取 SendKey")
                        .font(.arial(size: 11))
                        .foregroundStyle(Color(hex: "666666"))

                    TextField("推送标题", text: $viewModel.mobileAlertTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.arial(size: 12))
                    TextField("推送正文", text: $viewModel.mobileAlertBody)
                        .textFieldStyle(.roundedBorder)
                        .font(.arial(size: 12))

                    Text(viewModel.mobileConfigPathText)
                        .font(.arial(size: 10))
                        .foregroundStyle(Color(hex: "666666"))
                    Text(viewModel.currentIdleStateText)
                        .font(.arial(size: 11))
                        .foregroundStyle(Color(hex: "666666"))

                    HStack(spacing: 8) {
                        Button("保存手机推送配置") {
                            viewModel.saveMobilePushConfig()
                        }
                        .buttonStyle(.plain)
                        .font(.arial(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "B4DDF4"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Button("发送测试微信") {
                            viewModel.sendTestMobilePush()
                        }
                        .buttonStyle(.plain)
                        .font(.arial(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "F7DC7C"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Divider()

                    Text("步骤4：最近记录")
                        .font(.arial(size: 12, weight: .bold))

                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "FCFCFC"))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(hex: "E7D8CC"), lineWidth: 1)
                            }

                        if viewModel.history.isEmpty {
                            Text("暂无记录。完成一次弹窗选择后会显示在这里。")
                                .font(.arial(size: 13))
                                .foregroundStyle(Color(hex: "666666"))
                        } else {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 6) {
                                    ForEach(viewModel.history) { record in
                                        Text(viewModel.historyLine(for: record))
                                            .font(.arial(size: 11))
                                            .foregroundStyle(Color(hex: "1F1F1F"))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                }
                                .padding(8)
                            }
                        }
                    }
                    .frame(height: 260)

                    Button("刷新记录") {
                        viewModel.refreshHistory()
                    }
                    .buttonStyle(.plain)
                    .font(.arial(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "B4DDF4"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .foregroundStyle(Color(hex: "1F1F1F"))
            }
        }
        .frame(width: 500)
    }

    private var statusBar: some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.nextReminderText)
                    .font(.arial(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "1F1F1F"))
                Text(viewModel.statusText)
                    .font(.arial(size: 11))
                    .foregroundStyle(Color(hex: "666666"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HelpSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("使用说明")
                .font(.arial(size: 24, weight: .bold))

            Text("1. 添加目标")
                .font(.arial(size: 14, weight: .bold))
            Text("在左侧输入框写入目标，点击“添加目标”。")
                .font(.arial(size: 13))

            Text("2. 设置提醒间隔")
                .font(.arial(size: 14, weight: .bold))
            Text("设置基础间隔和最大间隔；开启智能间隔后，连续“正在完成”会逐步拉长提醒直到最大间隔。")
                .font(.arial(size: 13))

            Text("3. 手机告警（可选）")
                .font(.arial(size: 14, weight: .bold))
            Text("填写 Server酱 SendKey。可选开启“工作时段限制”，仅在设定时段内监控空闲并推送。")
                .font(.arial(size: 13))

            Text("4. 弹窗反馈")
                .font(.arial(size: 14, weight: .bold))
            Text("到时间会全屏弹窗，点击按钮或按键盘 1/2/3 选择当前状态。")
                .font(.arial(size: 13))

            Spacer()

            HStack {
                Spacer()
                Button("我知道了") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 620, height: 460)
        .background(Color(hex: "F6F2EE"))
    }
}
