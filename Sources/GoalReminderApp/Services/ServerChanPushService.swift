import Foundation

protocol MobilePushSending: Sendable {
    func sendIdleAlert(config: MobilePushConfig, idleSeconds: Double) async throws
    func sendTestAlert(config: MobilePushConfig) async throws
}

struct ServerChanPushService: MobilePushSending {
    private struct ServerChanResponse: Decodable {
        let code: Int?
        let message: String?
        let info: String?
    }

    func sendIdleAlert(config: MobilePushConfig, idleSeconds: Double) async throws {
        let message = "\(config.alertBody)（已空闲 \(Int(idleSeconds / 60)) 分钟）"
        try await send(config: config, title: config.alertTitle, body: message)
    }

    func sendTestAlert(config: MobilePushConfig) async throws {
        try await send(config: config, title: "连接测试", body: "这是来自目标提醒器的测试微信提醒。")
    }

    private func send(config: MobilePushConfig, title: String, body: String) async throws {
        let sendKey = config.serverChanSendKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sendKey.isEmpty else {
            throw AppError.invalidServerChanConfig("缺少 SendKey")
        }

        guard let url = URL(string: "https://sctapi.ftqq.com/\(sendKey).send") else {
            throw AppError.invalidServerChanConfig("SendKey 格式错误")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let hostName = Host.current().localizedName ?? "GoalReminderMac"
        let detail = "\(body)\n\n发送时间：\(timestamp)\n设备：\(hostName)"
        request.httpBody = formEncodedBody([
            "title": title,
            "desp": detail,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.serverChanSendFailed("Server酱 响应无效")
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AppError.serverChanSendFailed(message)
        }

        if let parsed = try? JSONDecoder().decode(ServerChanResponse.self, from: data),
           let code = parsed.code,
           code != 0
        {
            let message = parsed.message ?? parsed.info ?? "错误码 \(code)"
            throw AppError.serverChanSendFailed(message)
        }
    }

    private func formEncodedBody(_ dict: [String: String]) -> Data {
        let body = dict.map { key, value in
            "\(percentEncode(key))=\(percentEncode(value))"
        }
        .joined(separator: "&")
        return Data(body.utf8)
    }

    private func percentEncode(_ text: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }
}
