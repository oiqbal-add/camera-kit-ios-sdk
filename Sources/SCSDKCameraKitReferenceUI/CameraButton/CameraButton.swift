//  Copyright Snap Inc. All rights reserved.
//  CameraKit

import UIKit

/// Delegate to receive updates for camera button view
public protocol CameraButtonDelegate: AnyObject {
    /// Called when user taps camera button
    /// - Parameter cameraButton: camera button view
    func cameraButtonTapped(_ cameraButton: CameraButton)
}

/// Camera ring view for capturing and recording state
public class CameraButton: UIView, UIGestureRecognizerDelegate {
    public enum Constants {
        static let ringSize: CGFloat = 69.0
    }

    // MARK: Properties

    /// Camera button delegate
    public weak var delegate: CameraButtonDelegate?

    /// The minimum time for a hold to be considered "valid."
    /// If the user holds and releases for a duration shorter than specified, the camera button will act as though it has been tapped instead of held.
    public var minimumHoldDuration: TimeInterval = 0.75

    /// Line width for camera ring
    public var ringWidth: CGFloat {
        get {
            circleOutline.lineWidth
        }
        set {
            circleOutline.lineWidth = newValue
            circleFill.lineWidth = newValue / 1.2
        }
    }

    /// Ring color while recording
    public var ringColor: UIColor? {
        get {
            circleFill.strokeColor != nil ? UIColor(cgColor: circleFill.strokeColor!) : nil
        }
        set {
            circleFill.strokeColor = newValue?.cgColor
        }
    }

    /// Tap gesture recognizer that is used to recognize taps on the camera button
    /// to notify delegate that camera button was tapped to trigger an action (ie. capture)
    public private(set) lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapGestureRecognized(_:)))
        gestureRecognizer.delegate = self
        return gestureRecognizer
    }()

    // MARK: Views

    /// circle shape for outline of ring
    private let circleOutline: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = 6.0

        return layer
    }()

    /// circle shape for fill of ring
    private let circleFill: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor(hex: 0xFFFC00).cgColor
        layer.lineCap = CAShapeLayerLineCap.round
        layer.strokeStart = 0.0
        layer.strokeEnd = 0.0
        layer.lineWidth = 5.0

        return layer
    }()

    /// The time the hold started
    private var holdStartTime: Date?

    // MARK: Init

    public init() {
        super.init(frame: .zero)
        commonInit()
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        tapGestureRecognizer.view?.removeGestureRecognizer(tapGestureRecognizer)
    }

    private func commonInit() {
        isUserInteractionEnabled = true
        layer.addSublayer(circleOutline)
        layer.addSublayer(circleFill)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        
        addGestureRecognizer(tapGestureRecognizer)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        let radius = bounds.size.width / 2.0

        let path = UIBezierPath(
            arcCenter: CGPoint(x: radius, y: radius), radius: radius, startAngle: CGFloat.pi / -2.0,
            endAngle: 3 * CGFloat.pi / 2.0, clockwise: true
        )

        circleOutline.path = path.cgPath
        circleFill.path = path.cgPath
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: Constants.ringSize, height: Constants.ringSize)
    }

    // MARK: Gesture Recognizer

    override public func willMove(toSuperview newSuperview: UIView?) {
        tapGestureRecognizer.view?.removeGestureRecognizer(tapGestureRecognizer)
        newSuperview?.addGestureRecognizer(tapGestureRecognizer)
        super.willMove(toSuperview: newSuperview)
    }

    @objc
    private func tapGestureRecognized(_ sender: UITapGestureRecognizer) {
        delegate?.cameraButtonTapped(self)
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let point = touch.location(in: self)
        return point.x >= 0 && point.y >= 0 && point.x <= bounds.width && point.y <= bounds.height
    }
}

// MARK: Constants

private extension CameraButton.Constants {
    static let fillStrokeKey = "ring_fill_stroke_anim"
    static let fillColorKey = "ring_fill_color_anim"
    static let outlineIncreaseLineWidthKey = "ring_outline_increase_line_width_anim"
    static let outlineResetLineWidthKey = "ring_outline_reset_line_width_anim"
    static let sizeDuration = 0.25
}
