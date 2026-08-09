import AVFoundation
import AVKit
import UIKit

/// Fullscreen native player, the iOS counterpart of Android's `PlayerActivity`.
///
/// Renders through `AVPlayerLayer` rather than a Flutter texture: the same
/// reason the Android side uses a `SurfaceView` — a platform-composited
/// texture breaks the secure video path, and `AVPlayerLayer` is also the
/// surface a future FairPlay secure pipeline requires.
///
/// Plays unprotected and Lite DRM (AES-128 encrypted HLS) content. Lite DRM
/// needs no code here at all: AVPlayer fetches the `#EXT-X-KEY` key from the
/// playlist's key route itself.
final class ESitePlayerViewController: UIViewController {

    /// The player currently on screen. The plugin routes transport commands
    /// here, mirroring `PlayerActivity.current`.
    private(set) static weak var current: ESitePlayerViewController?

    private let seekInterval: Double = 10

    // Config
    private var config: [String: Any]
    private var sourceUrl: URL?
    private var httpHeaders: [String: String] = [:]
    private var autoPlay = false
    private var preventScreenRecording = false
    private var primaryColor: UIColor = .white
    private var secondaryColor: UIColor = .white

    // Playback
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var playerLayer: AVPlayerLayer?
    private var contentKeyManager: ESiteContentKeyManager?
    private var timeObserver: Any?
    private var volumeBeforeMute: Float = 1.0
    private var currentSpeed: Float = 1.0
    private var isSeeking = false
    private var hasReportedReady = false

    private var observations: [NSKeyValueObservation] = []

    // UI
    private let controlsOverlay = UIView()
    private let captureShield = UIView()
    private let playPauseButton = UIButton(type: .system)
    private let rewindButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let speedButton = UIButton(type: .system)
    private let qualityButton = UIButton(type: .system)
    private let audioButton = UIButton(type: .system)
    private let progressSlider = UISlider()
    private let positionLabel = UILabel()
    private let durationLabel = UILabel()
    private let titleLabel = UILabel()
    private let bufferingIndicator = UIActivityIndicatorView(style: .whiteLarge)
    private lazy var seekAnimationView = SeekAnimationView(secondsPerTap: Int(seekInterval))

    private let errorOverlay = UIView()
    private let errorTitleLabel = UILabel()
    private let errorMessageLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let errorCloseButton = UIButton(type: .system)

    private var controlsHideWorkItem: DispatchWorkItem?

    init(config: [String: Any]) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalPresentationCapturesStatusBarAppearance = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        Self.current = self
        view.backgroundColor = .black

        readConfig()
        buildUI()
        applyColors()
        observeScreenCapture()

        initializePlayer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
        seekAnimationView.frame = view.bounds
        captureShield.frame = view.bounds
    }

    override var prefersStatusBarHidden: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .allButUpsideDown
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed {
            teardown()
            PlayerEventBridge.shared.notifyPlayerDismissed()
        }
    }

    deinit {
        if Self.current === self { Self.current = nil }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Config

    private func readConfig() {
        if let urlString = config["sourceUrl"] as? String {
            sourceUrl = URL(string: urlString)
        }
        httpHeaders = config["headers"] as? [String: String] ?? [:]
        autoPlay = config["autoPlay"] as? Bool ?? false
        preventScreenRecording = (config["preventScreenRecording"] as? Bool ?? false)
            || (config["preventScreenshots"] as? Bool ?? false)

        if let primary = config["primaryColor"] as? NSNumber {
            primaryColor = UIColor(argb: primary.intValue)
        }
        if let secondary = config["secondaryColor"] as? NSNumber {
            secondaryColor = UIColor(argb: secondary.intValue)
        }
        titleLabel.text = config["title"] as? String
    }

    // MARK: - Player

    private func initializePlayer() {
        hideError()
        hasReportedReady = false

        guard let url = sourceUrl else {
            report(
                error: .invalidSource,
                title: "Invalid Source",
                message: "No video source URL provided"
            )
            return
        }

        let streamFormat = (config["streamFormat"] as? String)?.lowercased() ?? "auto"
        if streamFormat == "dash" {
            report(
                error: .unsupportedOnPlatform,
                title: "Unsupported Format",
                message: "DASH playback is not supported on iOS.\nThis content must be packaged as HLS."
            )
            return
        }

        let asset = AVURLAsset(
            url: url,
            options: httpHeaders.isEmpty
                ? nil
                : ["AVURLAssetHTTPHeaderFieldsKey": httpHeaders]
        )

        // Full DRM: wire the FairPlay seam. It reports a clear failure until
        // the service packages FairPlay HLS.
        if let drm = config["drm"] as? [String: Any],
           let licenseUrlString = drm["licenseUrl"] as? String,
           let licenseUrl = URL(string: licenseUrlString) {
            let manager = ESiteContentKeyManager(
                licenseUrl: licenseUrl,
                certificateUrl: (drm["certificateUrl"] as? String).flatMap(URL.init(string:)),
                licenseHeaders: drm["licenseHeaders"] as? [String: String] ?? [:]
            )
            manager.attach(to: asset)
            contentKeyManager = manager
        }

        let item = AVPlayerItem(asset: asset)
        playerItem = item

        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.automaticallyWaitsToMinimizeStalling = true
        player = avPlayer

        let layer = AVPlayerLayer(player: avPlayer)
        layer.videoGravity = .resizeAspect
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        playerLayer = layer

        observePlayer(avPlayer, item: item)
        configureAudioSession()

        PlayerEventBridge.shared.send(state: .initializing)

        avPlayer.rate = 0
        if autoPlay {
            avPlayer.playImmediately(atRate: currentSpeed)
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal: playback still works, it just may not duck other audio.
        }
    }

    private func observePlayer(_ avPlayer: AVPlayer, item: AVPlayerItem) {
        observations.append(
            item.observe(\.status, options: [.new]) { [weak self] item, _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    switch item.status {
                    case .readyToPlay:
                        if !self.hasReportedReady {
                            self.hasReportedReady = true
                            PlayerEventBridge.shared.send(state: .ready)
                        }
                        self.updateDurationLabel()
                        self.bufferingIndicator.stopAnimating()
                    case .failed:
                        self.handle(error: item.error)
                    default:
                        break
                    }
                }
            }
        )

        observations.append(
            item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] item, _ in
                DispatchQueue.main.async {
                    if item.isPlaybackBufferEmpty {
                        self?.bufferingIndicator.startAnimating()
                        PlayerEventBridge.shared.send(state: .buffering)
                    }
                }
            }
        )

        observations.append(
            item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
                DispatchQueue.main.async {
                    if item.isPlaybackLikelyToKeepUp {
                        self?.bufferingIndicator.stopAnimating()
                    }
                }
            }
        )

        observations.append(
            avPlayer.observe(\.timeControlStatus, options: [.new]) { [weak self] avPlayer, _ in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch avPlayer.timeControlStatus {
                    case .playing:
                        PlayerEventBridge.shared.send(state: .playing)
                        self.bufferingIndicator.stopAnimating()
                    case .paused:
                        if self.playerItem?.status == .readyToPlay {
                            PlayerEventBridge.shared.send(state: .paused)
                        }
                    case .waitingToPlayAtSpecifiedRate:
                        PlayerEventBridge.shared.send(state: .buffering)
                    @unknown default:
                        break
                    }
                    self.updatePlayPauseIcon()
                }
            }
        )

        timeObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.updateProgress(time)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStalled),
            name: .AVPlayerItemPlaybackStalled,
            object: item
        )
    }

    @objc private func playbackDidReachEnd() {
        PlayerEventBridge.shared.send(state: .completed)
        updatePlayPauseIcon()
        showControls()
    }

    @objc private func playbackStalled() {
        PlayerEventBridge.shared.send(state: .buffering)
        bufferingIndicator.startAnimating()
    }

    /// Maps AVFoundation failures onto the same error codes Android reports.
    private func handle(error: Error?) {
        let nsError = error as NSError?
        let message = nsError?.localizedDescription ?? "An unexpected error occurred during playback."

        let code: PlayerEventBridge.ErrorCode
        let title: String
        switch nsError?.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotConnectToHost, NSURLErrorTimedOut:
            code = .networkError
            title = "Network Error"
        case NSURLErrorFileDoesNotExist, NSURLErrorBadURL, NSURLErrorUnsupportedURL:
            code = .invalidSource
            title = "Content Not Found"
        case NSURLErrorUserAuthenticationRequired, NSURLErrorNoPermissionsToReadFile:
            code = .invalidSource
            title = "Access Denied"
        default:
            code = .playbackError
            title = "Playback Error"
        }

        report(error: code, title: title, message: message)
    }

    private func report(
        error: PlayerEventBridge.ErrorCode,
        title: String,
        message: String
    ) {
        showError(title: title, message: message)
        PlayerEventBridge.shared.send(state: .error)
        PlayerEventBridge.shared.send(
            error: error,
            message: message.replacingOccurrences(of: "\n", with: " ")
        )
        if error == .drmFailure {
            PlayerEventBridge.shared.send(
                drm: .licenseFailed,
                message: message.replacingOccurrences(of: "\n", with: " ")
            )
        }
    }

    private func teardown() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        NotificationCenter.default.removeObserver(self)
        contentKeyManager?.detach()
        contentKeyManager = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        if Self.current === self { Self.current = nil }
    }

    private func retryPlayback() {
        teardown()
        initializePlayer()
    }

    // MARK: - Screen capture protection

    /// iOS has no `FLAG_SECURE`. The closest available guarantee is reacting to
    /// capture: while the screen is being recorded or mirrored, the video layer
    /// is hidden and playback pauses. Screenshots cannot be blocked at all —
    /// only detected after the fact.
    private func observeScreenCapture() {
        guard preventScreenRecording else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenCaptureDidChange),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
        screenCaptureDidChange()
    }

    @objc private func screenCaptureDidChange() {
        let isCaptured = UIScreen.main.isCaptured
        captureShield.isHidden = !isCaptured
        if isCaptured {
            player?.pause()
        }
    }

    // MARK: - Transport commands (called by the plugin)

    func commandPlay() {
        player?.playImmediately(atRate: currentSpeed)
    }

    func commandPause() { player?.pause() }

    func commandSeek(toMilliseconds ms: Int64) {
        seek(to: CMTime(value: ms, timescale: 1000))
    }

    func commandSeekForward(milliseconds ms: Int64) {
        guard let current = player?.currentTime() else { return }
        seek(to: CMTimeAdd(current, CMTime(value: ms, timescale: 1000)))
    }

    func commandSeekBackward(milliseconds ms: Int64) {
        guard let current = player?.currentTime() else { return }
        let target = CMTimeSubtract(current, CMTime(value: ms, timescale: 1000))
        seek(to: CMTimeMaximum(target, .zero))
    }

    private func seek(to time: CMTime) {
        isSeeking = true
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.isSeeking = false
        }
    }

    func commandSetSpeed(_ speed: Float) {
        currentSpeed = speed
        // Setting rate on a paused player would start playback, so only apply
        // it live; otherwise it takes effect on the next play.
        if player?.timeControlStatus == .playing {
            player?.rate = speed
        }
    }

    func commandSetVolume(_ volume: Float) {
        if volume > 0 { volumeBeforeMute = volume }
        player?.volume = volume
    }

    func commandGetVolume() -> Double { Double(player?.volume ?? 1.0) }

    func commandSetMuted(_ muted: Bool) {
        if muted {
            let current = player?.volume ?? 1.0
            if current > 0 { volumeBeforeMute = current }
            player?.volume = 0
        } else {
            player?.volume = volumeBeforeMute
        }
    }

    func commandIsMuted() -> Bool { (player?.volume ?? 1.0) == 0 }

    func commandClose() {
        dismiss(animated: true) {
            PlayerEventBridge.shared.notifyPlayerDismissed()
        }
    }

    /// HLS variants, when the OS exposes them. Pre-iOS 15 only "auto" exists.
    func commandGetAvailableVideoTracks() -> [[String: Any]] {
        guard #available(iOS 15.0, *),
              let asset = playerItem?.asset as? AVURLAsset else { return [] }

        return asset.variants.enumerated().compactMap { index, variant in
            guard let size = variant.videoAttributes?.presentationSize else { return nil }
            let bitrate = Int(variant.peakBitRate ?? 0)
            return [
                "id": "\(index)",
                "label": "\(Int(size.height))p",
                "width": Int(size.width),
                "height": Int(size.height),
                "bitrate": bitrate,
                "frameRate": variant.videoAttributes?.nominalFrameRate ?? 0,
            ]
        }
    }

    /// AVPlayer has no direct variant override; quality is steered by capping
    /// the peak bitrate, which is the documented approach.
    func commandSetVideoTrack(_ trackId: String) {
        guard let item = playerItem else { return }
        if trackId == "auto" {
            item.preferredPeakBitRate = 0
            return
        }
        guard #available(iOS 15.0, *),
              let asset = item.asset as? AVURLAsset,
              let index = Int(trackId),
              index >= 0, index < asset.variants.count,
              let peak = asset.variants[index].peakBitRate else { return }
        item.preferredPeakBitRate = peak
    }

    func commandSetSubtitleEnabled(_ enabled: Bool) {
        guard let item = playerItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
        else { return }

        if enabled {
            let preferred = AVMediaSelectionGroup.mediaSelectionOptions(
                from: group.options,
                filteredAndSortedAccordingToPreferredLanguages: Locale.preferredLanguages
            ).first ?? group.options.first
            item.select(preferred, in: group)
        } else {
            item.select(nil, in: group)
        }
    }

    func commandIsSubtitleEnabled() -> Bool {
        guard let item = playerItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
        else { return false }
        return item.currentMediaSelection.selectedMediaOption(in: group) != nil
    }

    // Single-item playback, matching the Android behaviour.
    func commandHasNext() -> Bool { false }
    func commandHasPrevious() -> Bool { false }
    func commandNext() {}
    func commandPrevious() {}

    // MARK: - UI

    private func buildUI() {
        controlsOverlay.backgroundColor = UIColor(white: 0, alpha: 0.25)
        controlsOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsOverlay)
        NSLayoutConstraint.activate([
            controlsOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            controlsOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controlsOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        buildTransportControls()
        buildBottomBar()
        buildTopBar()
        buildErrorOverlay()

        bufferingIndicator.hidesWhenStopped = true
        bufferingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bufferingIndicator)
        NSLayoutConstraint.activate([
            bufferingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bufferingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        seekAnimationView.frame = view.bounds
        seekAnimationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(seekAnimationView, belowSubview: controlsOverlay)

        captureShield.backgroundColor = .black
        captureShield.isHidden = true
        captureShield.frame = view.bounds
        captureShield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(captureShield)

        setupGestures()
        scheduleControlsHide()
    }

    private func buildTransportControls() {
        let stack = UIStackView(arrangedSubviews: [rewindButton, playPauseButton, forwardButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 32
        stack.translatesAutoresizingMaskIntoConstraints = false

        configure(button: rewindButton, systemName: "gobackward.10", size: 34)
        configure(button: playPauseButton, systemName: "play.fill", size: 46)
        configure(button: forwardButton, systemName: "goforward.10", size: 34)

        rewindButton.addTarget(self, action: #selector(didTapRewind), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(didTapPlayPause), for: .touchUpInside)
        forwardButton.addTarget(self, action: #selector(didTapForward), for: .touchUpInside)

        controlsOverlay.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: controlsOverlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: controlsOverlay.centerYAnchor),
        ])
    }

    private func buildTopBar() {
        configure(button: closeButton, systemName: "xmark", size: 20)
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)

        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.numberOfLines = 1

        let stack = UIStackView(arrangedSubviews: [closeButton, titleLabel])
        stack.axis = .horizontal
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        controlsOverlay.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(
                equalTo: controlsOverlay.safeAreaLayoutGuide.topAnchor,
                constant: 12
            ),
            stack.leadingAnchor.constraint(
                equalTo: controlsOverlay.safeAreaLayoutGuide.leadingAnchor,
                constant: 16
            ),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: controlsOverlay.safeAreaLayoutGuide.trailingAnchor,
                constant: -16
            ),
        ])
    }

    private func buildBottomBar() {
        [positionLabel, durationLabel].forEach {
            $0.textColor = .white
            $0.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        }
        positionLabel.text = "0:00"
        durationLabel.text = "0:00"

        progressSlider.minimumValue = 0
        progressSlider.maximumValue = 1
        progressSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        progressSlider.addTarget(
            self,
            action: #selector(sliderTouchEnded),
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )

        configure(button: speedButton, systemName: "speedometer", size: 20)
        configure(button: qualityButton, systemName: "slider.horizontal.3", size: 20)
        configure(button: audioButton, systemName: "waveform", size: 20)
        speedButton.addTarget(self, action: #selector(didTapSpeed), for: .touchUpInside)
        qualityButton.addTarget(self, action: #selector(didTapQuality), for: .touchUpInside)
        audioButton.addTarget(self, action: #selector(didTapAudio), for: .touchUpInside)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let bottomRow = UIStackView(arrangedSubviews: [
            positionLabel, durationLabel, spacer, speedButton, qualityButton, audioButton,
        ])
        bottomRow.axis = .horizontal
        bottomRow.spacing = 16
        bottomRow.alignment = .center

        let column = UIStackView(arrangedSubviews: [progressSlider, bottomRow])
        column.axis = .vertical
        column.spacing = 8
        column.translatesAutoresizingMaskIntoConstraints = false
        controlsOverlay.addSubview(column)

        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(
                equalTo: controlsOverlay.safeAreaLayoutGuide.leadingAnchor,
                constant: 16
            ),
            column.trailingAnchor.constraint(
                equalTo: controlsOverlay.safeAreaLayoutGuide.trailingAnchor,
                constant: -16
            ),
            column.bottomAnchor.constraint(
                equalTo: controlsOverlay.safeAreaLayoutGuide.bottomAnchor,
                constant: -12
            ),
        ])
    }

    private func buildErrorOverlay() {
        errorOverlay.backgroundColor = UIColor(white: 0, alpha: 0.9)
        errorOverlay.isHidden = true
        errorOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorOverlay)
        NSLayoutConstraint.activate([
            errorOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            errorOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            errorOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        icon.tintColor = .systemYellow
        icon.contentMode = .scaleAspectFit

        errorTitleLabel.textColor = .white
        errorTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        errorTitleLabel.textAlignment = .center
        errorTitleLabel.numberOfLines = 0

        errorMessageLabel.textColor = UIColor(white: 1, alpha: 0.75)
        errorMessageLabel.font = .systemFont(ofSize: 14)
        errorMessageLabel.textAlignment = .center
        errorMessageLabel.numberOfLines = 0

        retryButton.setTitle("Retry", for: .normal)
        retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
        errorCloseButton.setTitle("Close", for: .normal)
        errorCloseButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [retryButton, errorCloseButton])
        buttons.axis = .horizontal
        buttons.spacing = 24
        buttons.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [
            icon, errorTitleLabel, errorMessageLabel, buttons,
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        errorOverlay.addSubview(stack)

        NSLayoutConstraint.activate([
            icon.heightAnchor.constraint(equalToConstant: 44),
            stack.centerYAnchor.constraint(equalTo: errorOverlay.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: errorOverlay.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: errorOverlay.trailingAnchor, constant: -32),
        ])
    }

    private func configure(button: UIButton, systemName: String, size: CGFloat) {
        let configuration = UIImage.SymbolConfiguration(pointSize: size, weight: .medium)
        button.setImage(UIImage(systemName: systemName, withConfiguration: configuration), for: .normal)
        button.tintColor = .white
    }

    private func applyColors() {
        progressSlider.minimumTrackTintColor = primaryColor
        progressSlider.thumbTintColor = primaryColor
        progressSlider.maximumTrackTintColor = primaryColor.withAlphaComponent(0.3)
        bufferingIndicator.color = primaryColor

        [playPauseButton, rewindButton, forwardButton, closeButton,
         speedButton, qualityButton, audioButton].forEach {
            $0.tintColor = secondaryColor
        }
        retryButton.setTitleColor(primaryColor, for: .normal)
        errorCloseButton.setTitleColor(secondaryColor, for: .normal)
    }

    // MARK: - Gestures and controls visibility

    private func setupGestures() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        view.addGestureRecognizer(singleTap)
    }

    @objc private func handleSingleTap() {
        if controlsOverlay.alpha > 0 {
            hideControls()
        } else {
            showControls()
        }
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: view)
        let forward = point.x > view.bounds.width / 2
        let ms = Int64(seekInterval * 1000)
        if forward {
            commandSeekForward(milliseconds: ms)
        } else {
            commandSeekBackward(milliseconds: ms)
        }
        seekAnimationView.showSeek(at: point, forward: forward)
    }

    private func showControls() {
        UIView.animate(withDuration: 0.2) { self.controlsOverlay.alpha = 1 }
        scheduleControlsHide()
    }

    private func hideControls() {
        controlsHideWorkItem?.cancel()
        UIView.animate(withDuration: 0.2) { self.controlsOverlay.alpha = 0 }
    }

    private func scheduleControlsHide() {
        controlsHideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.player?.timeControlStatus == .playing else { return }
            self.hideControls()
        }
        controlsHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }

    // MARK: - Control actions

    @objc private func didTapPlayPause() {
        if player?.timeControlStatus == .playing {
            commandPause()
        } else {
            commandPlay()
        }
        showControls()
    }

    @objc private func didTapRewind() {
        commandSeekBackward(milliseconds: Int64(seekInterval * 1000))
        showControls()
    }

    @objc private func didTapForward() {
        commandSeekForward(milliseconds: Int64(seekInterval * 1000))
        showControls()
    }

    @objc private func didTapClose() { commandClose() }

    @objc private func didTapRetry() { retryPlayback() }

    @objc private func sliderChanged() {
        guard let duration = playerItem?.duration.seconds, duration.isFinite else { return }
        positionLabel.text = Self.format(seconds: Double(progressSlider.value) * duration)
    }

    @objc private func sliderTouchEnded() {
        guard let duration = playerItem?.duration.seconds, duration.isFinite else { return }
        seek(to: CMTime(seconds: Double(progressSlider.value) * duration, preferredTimescale: 600))
        showControls()
    }

    @objc private func didTapSpeed(_ sender: UIButton) {
        let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0]
        presentMenu(
            title: "Playback speed",
            from: sender,
            options: speeds.map { speed in
                let checked = speed == currentSpeed ? "  ✓" : ""
                return ("\(speed)x\(checked)", { [weak self] in self?.commandSetSpeed(speed) })
            }
        )
    }

    @objc private func didTapQuality(_ sender: UIButton) {
        var options: [(String, () -> Void)] = [
            ("Auto (adaptive)", { [weak self] in self?.commandSetVideoTrack("auto") }),
        ]
        for track in commandGetAvailableVideoTracks() {
            guard let id = track["id"] as? String, let label = track["label"] as? String else { continue }
            options.append((label, { [weak self] in self?.commandSetVideoTrack(id) }))
        }
        presentMenu(title: "Quality", from: sender, options: options)
    }

    @objc private func didTapAudio(_ sender: UIButton) {
        guard let item = playerItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible),
              !group.options.isEmpty
        else {
            presentMenu(title: "Audio", from: sender, options: [("No audio tracks available", {})])
            return
        }

        let selected = item.currentMediaSelection.selectedMediaOption(in: group)
        var options: [(String, () -> Void)] = [
            ("Auto (default)", { [weak self] in
                self?.playerItem?.select(group.defaultOption, in: group)
            }),
        ]
        for option in group.options {
            let checked = option == selected ? "  ✓" : ""
            options.append((option.displayName + checked, { [weak self] in
                self?.playerItem?.select(option, in: group)
            }))
        }
        presentMenu(title: "Audio", from: sender, options: options)
    }

    private func presentMenu(
        title: String,
        from source: UIView,
        options: [(String, () -> Void)]
    ) {
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for (label, action) in options {
            sheet.addAction(UIAlertAction(title: label, style: .default) { _ in action() })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        // Required on iPad, where action sheets must be anchored.
        sheet.popoverPresentationController?.sourceView = source
        sheet.popoverPresentationController?.sourceRect = source.bounds
        present(sheet, animated: true)
        showControls()
    }

    // MARK: - UI updates

    private func updateProgress(_ time: CMTime) {
        guard !isSeeking, let duration = playerItem?.duration.seconds, duration.isFinite,
              duration > 0 else { return }
        let current = time.seconds
        progressSlider.value = Float(current / duration)
        positionLabel.text = Self.format(seconds: current)
    }

    private func updateDurationLabel() {
        guard let duration = playerItem?.duration.seconds, duration.isFinite else { return }
        durationLabel.text = "/ " + Self.format(seconds: duration)
    }

    private func updatePlayPauseIcon() {
        let playing = player?.timeControlStatus == .playing
        configure(
            button: playPauseButton,
            systemName: playing ? "pause.fill" : "play.fill",
            size: 46
        )
        playPauseButton.tintColor = secondaryColor
        if !playing { showControls() }
    }

    private func showError(title: String, message: String) {
        errorTitleLabel.text = title
        errorMessageLabel.text = message
        errorOverlay.isHidden = false
        bufferingIndicator.stopAnimating()
    }

    private func hideError() {
        errorOverlay.isHidden = true
    }

    private static func format(seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}

private extension UIColor {
    /// Builds a colour from Dart's `Color.toARGB32()`.
    convenience init(argb: Int) {
        self.init(
            red: CGFloat((argb >> 16) & 0xFF) / 255.0,
            green: CGFloat((argb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(argb & 0xFF) / 255.0,
            alpha: CGFloat((argb >> 24) & 0xFF) / 255.0
        )
    }
}
