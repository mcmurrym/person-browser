extension Task where Success == Never, Failure == Never {
    nonisolated static var isNotCancelled: Bool {
        !isCancelled
    }
}
