import Flutter
import UIKit

/// iOS entry point. Registers the same channels, method names and wire codes as
/// the Android plugin so one Dart implementation drives both platforms.
public class EsiteFlutterPlayerPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = EsiteFlutterPlayerPlugin()

        let methodChannel = FlutterMethodChannel(
            name: "esite_flutter_player/methods",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        FlutterEventChannel(
            name: "esite_flutter_player/events/state",
            binaryMessenger: registrar.messenger()
        ).setStreamHandler(StreamHandler(kind: .state))

        FlutterEventChannel(
            name: "esite_flutter_player/events/drm",
            binaryMessenger: registrar.messenger()
        ).setStreamHandler(StreamHandler(kind: .drm))

        FlutterEventChannel(
            name: "esite_flutter_player/events/error",
            binaryMessenger: registrar.messenger()
        ).setStreamHandler(StreamHandler(kind: .error))
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "launchPlayer", "initialize":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Expected a config map", details: nil))
                return
            }
            launchPlayer(config: args, result: result)

        case "dispose":
            ESitePlayerViewController.current?.commandClose()
            result(nil)

        default:
            handlePlayerCommand(call, result: result)
        }
    }

    private func launchPlayer(config: [String: Any], result: @escaping FlutterResult) {
        PlayerConfigHolder.set(config)

        guard let presenter = Self.topViewController() else {
            result(FlutterError(
                code: "NO_VIEW_CONTROLLER",
                message: "Could not find a view controller to present the player from",
                details: nil
            ))
            return
        }

        guard let pending = PlayerConfigHolder.take() else {
            result(FlutterError(code: "NO_CONFIG", message: "Player configuration was lost", details: nil))
            return
        }

        let playerViewController = ESitePlayerViewController(config: pending)
        presenter.present(playerViewController, animated: true) {
            result(nil)
        }
    }

    /// Transport commands go to the live player. With none on screen the call
    /// fails with NO_PLAYER rather than silently doing nothing, matching
    /// Android.
    private func handlePlayerCommand(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let player = ESitePlayerViewController.current else {
            result(FlutterError(code: "NO_PLAYER", message: "No player is currently active", details: nil))
            return
        }

        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "play":
            player.commandPlay()
            result(nil)
        case "pause":
            player.commandPause()
            result(nil)
        case "seekTo":
            player.commandSeek(toMilliseconds: Self.int64(args["positionMs"]))
            result(nil)
        case "seekForward":
            player.commandSeekForward(milliseconds: Self.int64(args["offsetMs"]))
            result(nil)
        case "seekBackward":
            player.commandSeekBackward(milliseconds: Self.int64(args["offsetMs"]))
            result(nil)
        case "setPlaybackSpeed":
            player.commandSetSpeed(Float(args["speed"] as? Double ?? 1.0))
            result(nil)
        case "setVolume":
            player.commandSetVolume(Float(args["volume"] as? Double ?? 1.0))
            result(nil)
        case "getVolume":
            result(player.commandGetVolume())
        case "setMuted":
            player.commandSetMuted(args["muted"] as? Bool ?? false)
            result(nil)
        case "isMuted":
            result(player.commandIsMuted())
        case "getAvailableVideoTracks":
            result(player.commandGetAvailableVideoTracks())
        case "setVideoTrack":
            guard let trackId = args["trackId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "trackId is required", details: nil))
                return
            }
            player.commandSetVideoTrack(trackId)
            result(nil)
        case "setSubtitleEnabled":
            player.commandSetSubtitleEnabled(args["enabled"] as? Bool ?? false)
            result(nil)
        case "isSubtitleEnabled":
            result(player.commandIsSubtitleEnabled())
        case "hasNext":
            result(player.commandHasNext())
        case "hasPrevious":
            result(player.commandHasPrevious())
        case "next":
            player.commandNext()
            result(nil)
        case "previous":
            player.commandPrevious()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private static func int64(_ value: Any?) -> Int64 {
        if let number = value as? NSNumber { return number.int64Value }
        return 0
    }

    /// Walks to the frontmost view controller so the player presents above
    /// whatever the app is currently showing.
    private static func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }

        var controller = keyWindow?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}

/// Routes each event channel's sink into the shared bridge.
private class StreamHandler: NSObject, FlutterStreamHandler {
    enum Kind { case state, drm, error }

    private let kind: Kind

    init(kind: Kind) {
        self.kind = kind
    }

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        switch kind {
        case .state: PlayerEventBridge.shared.stateSink = events
        case .drm: PlayerEventBridge.shared.drmSink = events
        case .error: PlayerEventBridge.shared.errorSink = events
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        switch kind {
        case .state: PlayerEventBridge.shared.stateSink = nil
        case .drm: PlayerEventBridge.shared.drmSink = nil
        case .error: PlayerEventBridge.shared.errorSink = nil
        }
        return nil
    }
}
