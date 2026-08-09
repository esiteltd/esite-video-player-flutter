import UIKit

/// Double-tap seek feedback, ported from the Android `SeekAnimationView`.
///
/// Fills the tapped half of the screen with a curved-edge overlay, expands a
/// ripple from the tap point, and shows the accumulated seek amount. Repeated
/// taps inside [accumulationWindow] add up, matching the Android behaviour.
final class SeekAnimationView: UIView {
    private let animationDuration: CFTimeInterval = 0.7
    private let accumulationWindow: TimeInterval = 0.9
    private let secondsPerTap: Int

    private var displayLink: CADisplayLink?
    private var animationStart: CFTimeInterval = 0
    private var tapPoint: CGPoint = .zero
    private var isForward = true
    private var accumulatedSeconds = 0
    private var resetWorkItem: DispatchWorkItem?

    private let label: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        return label
    }()

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    init(secondsPerTap: Int) {
        self.secondsPerTap = secondsPerTap
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isHidden = true
        addSubview(iconView)
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Registers a seek tap at [point] and (re)starts the animation.
    func showSeek(at point: CGPoint, forward: Bool) {
        if isForward != forward {
            accumulatedSeconds = 0
        }
        isForward = forward
        tapPoint = point
        accumulatedSeconds += secondsPerTap

        let amount = accumulatedSeconds
        label.text = forward ? "+\(amount) seconds" : "-\(amount) seconds"
        iconView.image = UIImage(named: forward ? "ic_forward_10" : "ic_replay_10")
            ?? Self.systemIcon(forward: forward)

        resetWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.accumulatedSeconds = 0 }
        resetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + accumulationWindow, execute: workItem)

        isHidden = false
        animationStart = CACurrentMediaTime()
        startDisplayLink()
        layoutContents()
    }

    private static func systemIcon(forward: Bool) -> UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: forward ? "goforward.10" : "gobackward.10")
        }
        return nil
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func step() {
        let elapsed = CACurrentMediaTime() - animationStart
        if elapsed >= animationDuration {
            stopDisplayLink()
            isHidden = true
            setNeedsDisplay()
            return
        }
        setNeedsDisplay()
    }

    private func layoutContents() {
        let halfWidth = bounds.width / 2
        let centerX = isForward ? bounds.width - halfWidth / 2 : halfWidth / 2
        let centerY = bounds.height / 2

        iconView.frame = CGRect(x: centerX - 24, y: centerY - 44, width: 48, height: 48)
        label.frame = CGRect(x: centerX - 80, y: centerY + 12, width: 160, height: 20)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutContents()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), !isHidden else { return }

        let elapsed = CACurrentMediaTime() - animationStart
        let t = min(max(elapsed / animationDuration, 0), 1)
        // Ease-out, matching Android: 1 - (1-t)^2
        let eased = 1 - pow(1 - t, 2)
        // Hold full opacity to the halfway point, then fade linearly.
        let alpha = t < 0.5 ? 1.0 : (1.0 - (t - 0.5) / 0.5)

        let halfWidth = bounds.width / 2
        let curveInset = halfWidth * 0.15

        // Half-screen shape with a curved inner edge.
        let path = UIBezierPath()
        if isForward {
            path.move(to: CGPoint(x: bounds.width, y: 0))
            path.addLine(to: CGPoint(x: halfWidth, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: halfWidth, y: bounds.height),
                controlPoint: CGPoint(x: halfWidth - curveInset, y: bounds.height / 2)
            )
            path.addLine(to: CGPoint(x: bounds.width, y: bounds.height))
        } else {
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: halfWidth, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: halfWidth, y: bounds.height),
                controlPoint: CGPoint(x: halfWidth + curveInset, y: bounds.height / 2)
            )
            path.addLine(to: CGPoint(x: 0, y: bounds.height))
        }
        path.close()

        context.saveGState()
        path.addClip()

        UIColor(white: 1, alpha: 40.0 / 255.0 * CGFloat(alpha)).setFill()
        context.fill(bounds)

        // Ripple expanding from the tap point.
        let maxRadius = max(bounds.width, bounds.height) * 0.5
        let radius = maxRadius * CGFloat(eased)
        UIColor(white: 1, alpha: 60.0 / 255.0 * CGFloat(alpha)).setFill()
        context.fillEllipse(
            in: CGRect(
                x: tapPoint.x - radius,
                y: tapPoint.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )

        context.restoreGState()

        iconView.alpha = CGFloat(alpha)
        label.alpha = CGFloat(alpha)
    }

    deinit {
        displayLink?.invalidate()
        resetWorkItem?.cancel()
    }
}
