import Foundation

actor MobilePushConfigStore {
    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folderURL = base.appendingPathComponent("GoalReminderSwift", isDirectory: true)
        try? fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        self.fileURL = folderURL.appendingPathComponent("mobile_push_config.json")
    }

    func configPath() -> String {
        fileURL.path
    }

    func load() -> MobilePushConfig {
        guard let data = try? Data(contentsOf: fileURL) else {
            return MobilePushConfig()
        }

        let decoder = JSONDecoder()
        guard let config = try? decoder.decode(MobilePushConfig.self, from: data) else {
            return MobilePushConfig()
        }
        return config
    }

    func save(_ config: MobilePushConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(config)
        try data.write(to: fileURL, options: .atomic)
    }
}
