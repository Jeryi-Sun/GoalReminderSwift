import Foundation

struct PythonBridgeResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

protocol PythonBridgeProviding: Sendable {
    func runInline(code: String) async throws -> PythonBridgeResult
}

struct PythonBridgeService: PythonBridgeProviding {
    func runInline(code: String) async throws -> PythonBridgeResult {
        try await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = ["-c", code]

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            try process.run()
            process.waitUntilExit()

            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outData, encoding: .utf8) ?? ""
            let error = String(data: errData, encoding: .utf8) ?? ""
            let result = PythonBridgeResult(exitCode: process.terminationStatus, stdout: output, stderr: error)

            guard result.exitCode == 0 else {
                throw AppError.pythonBridgeFailed(result.stderr.isEmpty ? "未知错误" : result.stderr)
            }

            return result
        }.value
    }
}
