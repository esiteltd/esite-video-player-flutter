import Foundation

/// Hands the player configuration to the view controller in memory.
///
/// Mirrors the Android holder: config can contain long token-bearing URLs, so
/// it is passed by reference rather than serialised.
enum PlayerConfigHolder {
    private static let lock = NSLock()
    private static var storedConfig: [String: Any]?

    static func set(_ config: [String: Any]) {
        lock.lock()
        defer { lock.unlock() }
        storedConfig = config
    }

    /// Returns the pending config and clears it.
    static func take() -> [String: Any]? {
        lock.lock()
        defer { lock.unlock() }
        let config = storedConfig
        storedConfig = nil
        return config
    }
}
