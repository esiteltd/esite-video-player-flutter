import Flutter
import Foundation

/// Relays player events to the Flutter event channels.
///
/// A singleton for the same reason as the Android one: the presented view
/// controller and the plugin instance cannot share references directly.
///
/// The integer codes here are the wire format and must stay in step with the
/// Dart enums and the Android implementation.
final class PlayerEventBridge {
    static let shared = PlayerEventBridge()

    private init() {}

    var stateSink: FlutterEventSink?
    var drmSink: FlutterEventSink?
    var errorSink: FlutterEventSink?

    /// Mirrors `ESitePlayerState`.
    enum State: Int {
        case idle = 0
        case initializing = 1
        case buffering = 2
        case ready = 3
        case playing = 4
        case paused = 5
        case completed = 6
        case error = 7
        case closed = 8
    }

    /// Mirrors `ESiteDrmEventType`.
    enum DrmEvent: Int {
        case licenseRequested = 0
        case licenseAcquired = 1
        case licenseFailed = 2
    }

    /// Mirrors `ESitePlayerErrorCode`. Only the codes native code can raise.
    enum ErrorCode: Int {
        case invalidSource = 0
        case drmFailure = 1
        case networkError = 2
        case playbackError = 3
        case unknown = 4
        case unsupportedOnPlatform = 8
    }

    func send(state: State) {
        onMain { self.stateSink?(state.rawValue) }
    }

    func send(drm: DrmEvent, message: String?) {
        onMain {
            self.drmSink?(["type": drm.rawValue, "message": message as Any])
        }
    }

    func send(error: ErrorCode, message: String) {
        onMain {
            self.errorSink?(["code": error.rawValue, "message": message])
        }
    }

    func notifyPlayerDismissed() {
        send(state: .closed)
    }

    func clear() {
        stateSink = nil
        drmSink = nil
        errorSink = nil
    }

    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
