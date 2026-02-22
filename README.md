# 目标提醒器 GoalReminderSwift

一个为「多进程忙一天，但晚上回看又觉得自己没真正推进核心目标」的人做的 macOS 提醒工具。

## 创建初衷

我做这个 App 的原因很直接：

当你同时开很多任务（消息、会议、临时问题、上下文切换）时，很容易在“看起来一直很忙”里消耗掉整天，却没在最重要目标上持续前进。

`GoalReminderSwift` 通过“周期性全屏追问”把你拉回主线：

- 你现在是否在推进目标？
- `已完成 / 正在完成 / 马上去完成`

核心目的不是制造压力，而是降低“忙碌幻觉”，让注意力不断回到真正重要的事上。

## 技术栈

- Language: `Swift`
- UI: `SwiftUI` + `AppKit`（全屏提醒窗口）
- IDE: `Xcode`
- Notification: `Server酱·Turbo`（微信推送）
- ML: `Core ML`（已预留接口）
- Python bridge: `Process` 调用本机 `python3`（已预留接口）
- Tools: `Git`, `Homebrew`

## 使用界面截图

### 主界面

![主界面](assets/screenshots/main-ui.png)

说明：上图展示了最新版本的设置项，包括智能间隔、弹窗透明度、倒计时、Server酱 微信推送与工作时段限制。

### 全屏提醒弹窗

![全屏提醒](assets/screenshots/fullscreen-reminder.png)

说明：全屏提醒已支持“非激活悬浮显示”（尽量减少应用切换感），并可在设置中调整背景遮罩透明度。

## 功能

- 目标新增 / 删除 / 选择
- 提醒间隔设置（分钟）
- 智能间隔：连续多次选择“正在完成”时自动拉长提醒间隔，直到你设置的最大间隔
- 定时全屏提醒弹窗（`1 已完成` / `2 正在完成` / `3 马上去完成`）
- 已有未处理弹窗时，后续提醒自动跳过（不重复叠弹）
- 全屏弹窗倒计时显示：支持设置截止日期时间，在弹窗和主界面显示剩余时间（天/小时/min）
- 全屏弹窗透明度可调：支持设置背景遮罩透明度，形成更柔和的悬浮提醒体验
- 非激活悬浮提醒：弹窗尽量悬浮在当前应用之上，减少“先切走再切回”的感觉
- 电脑端空闲检测：鼠标/键盘连续无操作达到阈值（默认 20 分钟）时，自动触发手机告警
- Server酱 微信推送：空闲达到阈值时自动推送到微信
- 空闲推送工作时段限制：仅在指定时段内触发（支持跨午夜）
- 历史记录追踪
- 本地持久化存储

## 使用方案（推荐）

1. 每天开始工作前，先添加 1~3 个当天最重要目标。
2. 提醒策略建议：基础间隔 `10~30` 分钟，最大间隔设为基础的 `1.5~3` 倍；弹窗透明度建议先设在 `25%~45%`。
3. 如有明确截止时间（投稿、汇报、DDL），设置倒计时并在提醒弹窗里持续看到剩余时间。
4. 弹窗出现时，必须立刻做出一个选择，不跳过。
5. 如需空闲微信提醒，开启工作时段限制（例如 `09:00-12:00`、`13:00-18:30` 这种主工作区间）。
6. 每天结束前看“最近记录”：
   你会清楚看到自己是持续推进，还是频繁偏离。

## 快速开始

### 直接使用打包版本（推荐）

仓库已包含打包文件：

- `release/GoalReminderSwift.app.zip`

使用方式：

1. 下载并解压 `GoalReminderSwift.app.zip`
2. 双击 `GoalReminderSwift.app`
3. 如果首次被系统拦截，右键应用选择“打开”

注意：

- 不要直接点 `Contents/MacOS/GoalReminderApp`
- 当前打包版本主要面向 Apple Silicon（M 系列）

### 启用微信提醒（Server酱）

1. 打开 [Server酱·Turbo](https://sct.ftqq.com/) 并登录
2. 在控制台创建消息通道，拿到 `SendKey`（格式类似 `SCTxxxxxxxxxx`）
3. 打开本应用，在“手机端告警”区域填入 `SendKey`
4. 设定空闲阈值（默认 20 分钟），可选开启工作时段限制并填写 `HH:mm` 起止时间
5. 点击“发送测试微信”确认你能收到提醒

说明：

- 这种方案不需要开发 iOS App，也不需要 Apple Developer 证书。
- 微信通知是否显示横幅/声音，取决于你手机系统和微信通知设置。

### 本地源码运行

```bash
cd /Users/sunzhongxiang/Desktop/科研/development_tools/target_remainder/GoalReminderSwift
swift build
swift run GoalReminderApp
```

### 在 Xcode 中运行

1. 打开 Xcode
2. `File -> Open...`
3. 选择本目录 `GoalReminderSwift`
4. 运行 `GoalReminderApp` target

## 工程结构

- `Package.swift`: Swift Package 配置
- `Sources/GoalReminderApp/App`: 应用入口
- `Sources/GoalReminderApp/ViewModels`: 状态管理与调度逻辑
- `Sources/GoalReminderApp/Views`: SwiftUI 主界面与提醒视图
- `Sources/GoalReminderApp/Data`: 本地数据存储
- `Sources/GoalReminderApp/Services`: Core ML / Python bridge / 全屏弹窗管理 / Server酱 推送
- `assets/screenshots`: README 使用截图
- `release`: 打包好的可执行 App 压缩包

## Core ML 与 Python bridge

- Core ML 接口文件：`Sources/GoalReminderApp/Services/GoalInsightEngine.swift`
- Python bridge 文件：`Sources/GoalReminderApp/Services/PythonBridgeService.swift`

当前为稳定占位实现，后续可以接入你自己的模型和 Python 脚本。

## 数据文件位置

运行后数据保存在：

- `~/Library/Application Support/GoalReminderSwift/state.json`
- `~/Library/Application Support/GoalReminderSwift/mobile_push_config.json`
