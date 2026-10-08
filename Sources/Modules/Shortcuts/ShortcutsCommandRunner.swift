import Foundation

enum ShortcutsCommandResult: Sendable, Equatable {
    case success(String)
    case failed
    case timedOut
    case cancelled
}

protocol ShortcutsCommandRunning: Sendable {
    func output(arguments: [String], timeout: Duration) async -> ShortcutsCommandResult
}

struct SystemShortcutsCommandRunner: ShortcutsCommandRunning {
    func output(arguments: [String], timeout: Duration) async -> ShortcutsCommandResult {
        let controller = ShortcutsProcessController()
        return await withTaskGroup(of: ShortcutsCommandResult.self) { group in
            group.addTask {
                await execute(arguments: arguments, controller: controller)
            }
            group.addTask {
                do {
                    try await Task.sleep(for: timeout)
                } catch {
                    controller.requestTermination(reason: .cancelled)
                    return .cancelled
                }
                controller.requestTermination(reason: .timedOut)
                return .timedOut
            }

            let firstResult = await group.next() ?? .failed
            group.cancelAll()
            if Task.isCancelled {
                controller.requestTermination(reason: .cancelled)
                return .cancelled
            }
            return firstResult
        }
    }

    private func execute(
        arguments: [String],
        controller: ShortcutsProcessController
    ) async -> ShortcutsCommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                process.arguments = arguments
                let output = Pipe()
                process.standardOutput = output
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                    controller.install(process)
                } catch {
                    continuation.resume(returning: controller.terminationReason ?? .failed)
                    return
                }
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if let terminationReason = controller.terminationReason {
                    continuation.resume(returning: terminationReason)
                } else if process.terminationStatus == 0,
                          let string = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: .success(string))
                } else {
                    continuation.resume(returning: .failed)
                }
            }
        }
    }
}

/// Synchronise l'accès au `Process`, créé sur une file de fond mais interrompu par
/// l'annulation Swift ou par le timeout.
private final class ShortcutsProcessController: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var pendingTerminationReason: ShortcutsCommandResult?

    var terminationReason: ShortcutsCommandResult? {
        lock.lock()
        defer { lock.unlock() }
        return pendingTerminationReason
    }

    func install(_ process: Process) {
        lock.lock()
        self.process = process
        let mustTerminate = pendingTerminationReason != nil
        lock.unlock()
        if mustTerminate, process.isRunning { process.terminate() }
    }

    func requestTermination(reason: ShortcutsCommandResult) {
        lock.lock()
        if pendingTerminationReason == nil { pendingTerminationReason = reason }
        let process = process
        lock.unlock()
        if let process, process.isRunning { process.terminate() }
    }
}
