//  Copyright Snap Inc. All rights reserved.
//  CameraKit

import Photos
import UIKit

/// Base preview view controller that describes properties and views of all preview controllers
public class PreviewViewController: UIViewController {
    // MARK: Preview Properties

    /// Snapchat delegate for open requests
    public weak var snapchatDelegate: SnapchatDelegate? {
        didSet {
            snapchatButton.isHidden = snapchatDelegate == nil
        }
    }

    /// Callback when user presses close button and dismisses preview view controller
    public var onDismiss: (() -> Void)?

    // MARK: View Properties

    fileprivate let closeButton: UIButton = {
        let button = UIButton()
        button.accessibilityIdentifier = PreviewElements.closeButton.id
        button.setImage(
            UIImage(named: "ck_close_x", in: BundleHelper.resourcesBundle, compatibleWith: nil), for: .normal
        )
        button.translatesAutoresizingMaskIntoConstraints = false

        return button
    }()

    fileprivate let snapchatButton: UIButton = {
        let button = UIButton()
        button.accessibilityIdentifier = PreviewElements.snapchatButton.id
        button.isHidden = true
        button.setImage(
            UIImage(named: "ck_snapchat_app_icon", in: BundleHelper.resourcesBundle, compatibleWith: nil), for: .normal
        )
        button.translatesAutoresizingMaskIntoConstraints = false

        return button
    }()

    fileprivate let saveButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "ck_save", in: BundleHelper.resourcesBundle, compatibleWith: nil), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false

        return button
    }()

    internal let shareButton: UIButton = {
        let button = UIButton()
        button.accessibilityIdentifier = PreviewElements.shareButton.id
        button.setImage(UIImage(named: "ck_share", in: BundleHelper.resourcesBundle, compatibleWith: nil), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    internal let printButton: UIButton = {
        let button = UIButton()
        button.accessibilityIdentifier = "PrintButton"
        button.setImage(UIImage(systemName: "printer"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    internal let qrCodeButton: UIButton = {
        let button = UIButton()
        button.accessibilityIdentifier = "QRCodeButton"
        button.setImage(UIImage(systemName: "qrcode"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    internal lazy var bottomButtonStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [shareButton, printButton, qrCodeButton])
        stackView.alignment = .center
        stackView.axis = .horizontal
        stackView.distribution = .equalCentering
        stackView.spacing = 70.0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: Setup

    override public func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    private func setup() {
        view.backgroundColor = .black
        setupCloseButton()
        setupBottomButtonBar()
    }

    // MARK: Overridable Actions

    @objc
    open func openSnapchatPressed(_ sender: UIButton) {
        fatalError("open Snapchat action has to be implemented by subclass")
    }

    @objc
    open func savePreviewPressed(_ sender: UIButton) {
        fatalError("save preview action has to be implemented by subclass")
    }

    @objc
    open func sharePreviewPressed(_ sender: UIButton) {
        fatalError("share preview action has to be implemented by subclass")
    }

    @objc
    open func printButtonPressed(_ sender: UIButton) {
        fatalError("print action has to be implemented by subclass")
    }

    @objc
    open func qrCodeButtonPressed(_ sender: UIButton) {
        fatalError("QR code action has to be implemented by subclass")
    }
}

// MARK: Close Button

extension PreviewViewController {
    private func setupCloseButton() {
        closeButton.addTarget(self, action: #selector(closeButtonPressed(_:)), for: .touchUpInside)
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32.0),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16.0),
        ])
    }

    @objc
    private func closeButtonPressed(_ sender: UIButton) {
        onDismiss?()
        dismiss(animated: true, completion: nil)
    }
}

// MARK: Bottom Button Bar

extension PreviewViewController {
    private func setupBottomButtonBar() {
        shareButton.addTarget(self, action: #selector(sharePreviewPressed(_:)), for: .touchUpInside)
        printButton.addTarget(self, action: #selector(printButtonPressed(_:)), for: .touchUpInside)
        qrCodeButton.addTarget(self, action: #selector(qrCodeButtonPressed(_:)), for: .touchUpInside)
        
        view.addSubview(bottomButtonStackView)
        
        // Make buttons bigger
        [shareButton, printButton, qrCodeButton].forEach { button in
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 80),
                button.heightAnchor.constraint(equalToConstant: 80)
            ])
        }
        
        NSLayoutConstraint.activate([
            bottomButtonStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomButtonStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40.0),
            bottomButtonStackView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8)
        ])
    }

    @objc
    private func savePreviewPressedWithAuthorization(_ sender: UIButton) {
        guard PHPhotoLibrary.authorizationStatus() == .authorized else {
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized else { return }
                self.savePreviewPressed(sender)
            }

            return
        }
        savePreviewPressed(sender)
    }
}
