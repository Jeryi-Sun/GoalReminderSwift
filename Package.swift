// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GoalReminderSwift",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "GoalReminderApp", targets: ["GoalReminderApp"])
    ],
    targets: [
        .executableTarget(
            name: "GoalReminderApp",
            path: "Sources/GoalReminderApp"
        )
    ]
)
