// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// One callback operation, serialized on the main actor. Timeout and cancellation
/// resume the same continuation as the callback; late callbacks are ignored.
@MainActor
final class CallbackWaiter<Value> {
    private var continuation: CheckedContinuation<Value, Error>?
    private var deadline: Task<Void, Never>?
    private var started = false
    private(set) var isFinished = false

    func wait(timeout: TimeInterval, timeoutError: Error,
              start: () -> Void) async throws -> Value {
        precondition(!started, "A callback waiter can only be used once")
        started = true
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                continuation = cont
                guard !Task.isCancelled else {
                    resolve(.failure(CancellationError()))
                    return
                }
                deadline = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: UInt64(max(0, timeout) * 1_000_000_000)) }
                    catch { return }
                    self?.resolve(.failure(timeoutError))
                }
                start()
            }
        } onCancel: {
            Task { @MainActor in self.resolve(.failure(CancellationError())) }
        }
    }

    func resolve(_ result: Result<Value, Error>) {
        guard let continuation, !isFinished else { return }
        isFinished = true
        self.continuation = nil
        deadline?.cancel()
        deadline = nil
        continuation.resume(with: result)
    }
}
