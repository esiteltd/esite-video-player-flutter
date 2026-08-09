import AVFoundation
import Foundation

/// FairPlay Streaming seam.
///
/// Full-DRM content is currently packaged as DASH + Widevine, which AVPlayer
/// cannot play at all. Playing it on iOS needs the video service to also
/// package CBCS fMP4 HLS and expose a FairPlay SPC/CKC endpoint plus an
/// application certificate — that work is pending.
///
/// This type exists so the wiring is in one place when it lands: it already
/// tracks the `AVContentKeySession` lifecycle and reports DRM events, and only
/// the certificate fetch and CKC exchange in `handleKeyRequest` are stubbed.
/// Lite DRM does **not** go through here — AES-128 HLS keys are fetched by
/// AVPlayer itself from the playlist's key route.
final class ESiteContentKeyManager: NSObject {
    /// License server endpoint (CKC exchange).
    private let licenseUrl: URL
    /// Application certificate URL, issued by Apple to the content provider.
    private let certificateUrl: URL?
    private let licenseHeaders: [String: String]

    private var contentKeySession: AVContentKeySession?

    init(licenseUrl: URL, certificateUrl: URL?, licenseHeaders: [String: String]) {
        self.licenseUrl = licenseUrl
        self.certificateUrl = certificateUrl
        self.licenseHeaders = licenseHeaders
        super.init()
    }

    /// Whether FairPlay can actually be performed. False until the backend
    /// ships an application certificate and CKC endpoint.
    var isAvailable: Bool { certificateUrl != nil }

    func attach(to asset: AVURLAsset) {
        let session = AVContentKeySession(keySystem: .fairPlayStreaming)
        session.setDelegate(self, queue: DispatchQueue(label: "com.esite.player.contentkey"))
        session.addContentKeyRecipient(asset)
        contentKeySession = session
    }

    func detach() {
        contentKeySession?.setDelegate(nil, queue: nil)
        contentKeySession = nil
    }

    private func handleKeyRequest(_ keyRequest: AVContentKeyRequest) {
        PlayerEventBridge.shared.send(drm: .licenseRequested, message: "FairPlay key requested")

        // Remaining work when the backend is ready:
        //   1. GET certificateUrl -> application certificate (DER)
        //   2. keyRequest.makeStreamingContentKeyRequestData(forApp:contentIdentifier:)
        //   3. POST the SPC to licenseUrl with licenseHeaders -> CKC
        //   4. keyRequest.processContentKeyResponse(AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckc))
        let message = "FairPlay licensing is not available from the video service yet."
        PlayerEventBridge.shared.send(drm: .licenseFailed, message: message)
        PlayerEventBridge.shared.send(error: .unsupportedOnPlatform, message: message)
        keyRequest.processContentKeyResponseError(
            NSError(
                domain: "com.esite.player",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        )
    }
}

extension ESiteContentKeyManager: AVContentKeySessionDelegate {
    func contentKeySession(
        _ session: AVContentKeySession,
        didProvide keyRequest: AVContentKeyRequest
    ) {
        handleKeyRequest(keyRequest)
    }

    func contentKeySession(
        _ session: AVContentKeySession,
        didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest
    ) {
        handleKeyRequest(keyRequest)
    }

    func contentKeySession(
        _ session: AVContentKeySession,
        contentKeyRequest keyRequest: AVContentKeyRequest,
        didFailWithError err: Error
    ) {
        PlayerEventBridge.shared.send(
            drm: .licenseFailed,
            message: "FairPlay key request failed: \(err.localizedDescription)"
        )
    }
}
