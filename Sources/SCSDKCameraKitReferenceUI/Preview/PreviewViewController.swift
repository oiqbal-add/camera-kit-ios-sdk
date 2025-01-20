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

    internal let airDropButton: UIButton = {
        let button = UIButton()
        button.accessibilityIdentifier = "AirDropButton"
        
        // Use a simple share icon
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        button.setImage(UIImage(systemName: "square.and.arrow.up")?.withConfiguration(config), for: .normal)
        button.setTitle("AirDrop", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12)
        
        // Setup vertical layout
        button.tintColor = .white
        button.setTitleColor(.white, for: .normal)
        
        // Center image and text vertically
        button.imageEdgeInsets = UIEdgeInsets(top: -15, left: 0, bottom: 0, right: 0)
        button.titleEdgeInsets = UIEdgeInsets(top: 30, left: -30, bottom: -30, right: 0)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    internal let saveButton: UIButton = {
        let button = UIButton()
        button.accessibilityIdentifier = "SaveButton"
        button.setImage(UIImage(systemName: "square.and.arrow.down"), for: .normal)
        button.tintColor = .white
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
        let stackView = UIStackView(arrangedSubviews: [airDropButton, printButton, qrCodeButton])
        stackView.alignment = .center
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.spacing = 70
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
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
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
        // Configure all buttons similarly
        [printButton, qrCodeButton].forEach { button in
            button.setTitle(button == printButton ? "Print" : "QR Code", for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 12)
            button.setTitleColor(.white, for: .normal)
            button.imageEdgeInsets = UIEdgeInsets(top: -15, left: 0, bottom: 0, right: 0)
            button.titleEdgeInsets = UIEdgeInsets(top: 30, left: -30, bottom: -30, right: 0)
        }
        
        // Setup bottom bar
        let bottomBar = UIView()
        bottomBar.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)
        view.addSubview(bottomButtonStackView)
        
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 100),
            
            bottomButtonStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomButtonStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            bottomButtonStackView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8)
        ])
        
        // Add actions
        airDropButton.addTarget(self, action: #selector(sharePreviewPressed(_:)), for: .touchUpInside)
        printButton.addTarget(self, action: #selector(printButtonPressed(_:)), for: .touchUpInside)
        qrCodeButton.addTarget(self, action: #selector(qrCodeButtonPressed(_:)), for: .touchUpInside)
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
