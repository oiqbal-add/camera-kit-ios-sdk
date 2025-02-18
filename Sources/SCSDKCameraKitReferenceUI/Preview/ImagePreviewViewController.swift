//  Copyright Snap Inc. All rights reserved.
//  CameraKit

import Photos
import UIKit
import CoreImage.CIFilterBuiltins

/// Preview view controller for showing captured photos and images
public class ImagePreviewViewController: PreviewViewController {
    // MARK: Properties

    /// UIImage to display
    public let image: UIImage

    fileprivate lazy var imageView: UIImageView = {
        let view = UIImageView(image: image)
        view.accessibilityIdentifier = PreviewElements.imageView.id
        view.contentMode = .scaleAspectFill
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    // Add timer property
    private var inactivityTimer: Timer?
    private let inactivityTimeout: TimeInterval = 120.0 // 2 minutes

    // Add property to track QR code view controller
    private weak var activeQRViewController: UIViewController?

    // MARK: Init

    /// Designated init to pass in required deps
    /// - Parameter image: UIImage to display
    public init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        // Don't call super.viewDidLoad() since we want to completely override the parent's setup
        modalPresentationStyle = .overFullScreen
        setupUI()
        startInactivityTimer()
        
        // Add gesture recognizer to track user interaction
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(userDidInteract))
        view.addGestureRecognizer(tapGesture)
        
        // Add pan gesture recognizer
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(userDidInteract))
        view.addGestureRecognizer(panGesture)
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopInactivityTimer()
    }

    // MARK: Setup

    private func setupUI() {
        view.backgroundColor = .clear
        
        // Create frosted glass effect
        let blurEffect = UIBlurEffect(style: .systemMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.layer.cornerRadius = 24
        blurView.clipsToBounds = true
        view.addSubview(blurView)
        
        // Setup image view with consistent corner radius
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 20
        imageView.layer.masksToBounds = true
        
        // Create a container view for the image to maintain corner radius
        let imageContainer = UIView()
        imageContainer.backgroundColor = .clear
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        imageContainer.clipsToBounds = true
        imageContainer.layer.cornerRadius = 20
        view.addSubview(imageContainer)
        
        // Add image view to container
        imageContainer.addSubview(imageView)
        
        // Setup close button
        let closeButton = UIButton()
        closeButton.setImage(
            UIImage(named: "ck_close_x", in: BundleHelper.resourcesBundle, compatibleWith: nil), 
            for: .normal
        )
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeButtonPressed), for: .touchUpInside)
        view.addSubview(closeButton)
        
        // Setup button stack
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.distribution = .equalSpacing
        buttonStack.alignment = .center
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)
        
        // Configure action buttons
        let buttonConfigs: [(String, String, UIColor)] = [
            ("AirDrop", "square.and.arrow.up.fill", UIColor(red: 0.53, green: 0.44, blue: 0.95, alpha: 1)),  // Purple
            ("Print", "printer.fill", UIColor(red: 0.75, green: 0.45, blue: 0.7, alpha: 1)),  // Mid gradient
            ("QR Code", "qrcode", UIColor(red: 0.98, green: 0.45, blue: 0.45, alpha: 1))  // Orange-Pink
        ]
        
        buttonConfigs.forEach { (title, iconName, _) in
            let button = createActionButton(icon: iconName, title: title, color: .white)
            buttonStack.addArrangedSubview(button)
            
            // Add tap handlers
            switch title {
            case "AirDrop":
                button.addTarget(self, action: #selector(airDropButtonPressed(_:)), for: .touchUpInside)
            case "Print":
                button.addTarget(self, action: #selector(printButtonPressed(_:)), for: .touchUpInside)
            case "QR Code":
                button.addTarget(self, action: #selector(qrCodeButtonPressed(_:)), for: .touchUpInside)
            default:
                break
            }
            
            // Add highlight effects
            button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: .touchUpInside)
        }
        
        // Add copyright label
        let copyrightLabel = setupGradientCopyrightLabel()
        view.addSubview(copyrightLabel)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Close button constraints - positioned relative to container view
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Image container constraints - use these instead of direct imageView constraints
            imageContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            imageContainer.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            imageContainer.heightAnchor.constraint(equalTo: imageContainer.widthAnchor, multiplier: image.size.height / image.size.width),
            
            // Image view constraints within container
            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            
            // Button stack constraints
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            
            // Copyright label constraints - aligned with close button
            copyrightLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            copyrightLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
        
        // Ensure close button stays on top
        view.bringSubviewToFront(closeButton)
        
        // Make sure copyright label stays on top
        view.bringSubviewToFront(copyrightLabel)
    }

    private func createActionButton(icon: String, title: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Create stack view for perfect alignment
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure icon
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let iconImageView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        
        // Configure label
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        
        // Add to stack view
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(label)
        
        // Add stack view to button
        button.addSubview(stackView)
        
        // Center stack view in button
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: button.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: button.trailingAnchor, constant: -8),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        
        // Make sure the entire button is tappable
        button.isUserInteractionEnabled = true
        stackView.isUserInteractionEnabled = false
        
        return button
    }

    @objc private func buttonTapped(_ sender: UIButton) {
        // Add subtle animation on tap
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                sender.transform = .identity
            }
        }
        
        // Handle existing button actions
        if sender == airDropButton {
            airDropButtonPressed(sender)
        } else if sender == printButton {
            printButtonPressed(sender)
        } else if sender == qrCodeButton {
            qrCodeButtonPressed(sender)
        }
    }

    @objc private func airDropButtonPressed(_ sender: UIButton) {
        userDidInteract()
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        // Exclude everything except AirDrop
        activityVC.excludedActivityTypes = [
            .addToReadingList, .assignToContact, .copyToPasteboard,
            .mail, .message, .postToFacebook, .postToTwitter,
            .postToWeibo, .print, .saveToCameraRoll, .markupAsPDF
        ]
        
        // Position the popover above the button
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = sender
            popoverController.sourceRect = sender.bounds
            popoverController.permittedArrowDirections = .down
            popoverController.popoverLayoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)
        }
        
        present(activityVC, animated: true)
    }

    @objc private func saveButtonPressed(_ sender: UIButton) {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if status == .authorized {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAsset(from: self.image)
                    }) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                self.showAlert(title: "Saved!", message: "Photo saved to your library")
                            } else {
                                self.showAlert(title: "Error", message: "Failed to save photo: \(error?.localizedDescription ?? "Unknown error")")
                            }
                        }
                    }
                } else {
                    self.showAlert(
                        title: "Permission Required",
                        message: "Please allow access to your photo library in Settings to save photos"
                    )
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: Action Overrides

    override public func openSnapchatPressed(_ sender: UIButton) {
        userDidInteract()
        snapchatDelegate?.cameraKitViewController(self, openSnapchat: .photo(image))
    }

    override public func sharePreviewPressed(_ sender: UIButton) {
        userDidInteract()
        shareViaAirDrop()
    }

    private func shareViaAirDrop() {
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        // Limit to AirDrop only
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .copyToPasteboard,
            .mail,
            .message,
            .postToFacebook,
            .postToTwitter,
            .postToWeibo,
            .print,
            .saveToCameraRoll
        ]
        
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }

    @objc override public func printButtonPressed(_ sender: UIButton) {
        userDidInteract()
        
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .photo
        printInfo.jobName = "PicPop Photo"
        
        printController.printInfo = printInfo
        printController.printingItem = image
        
        // Present as popover on iPad, modal on iPhone
        if UIDevice.current.userInterfaceIdiom == .pad {
            printController.present(from: sender.bounds, in: sender, animated: true)
        } else {
            printController.present(from: sender.bounds, in: sender, animated: true)
        }
    }

    @objc override public func qrCodeButtonPressed(_ sender: UIButton) {
        userDidInteract()
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Generating...", message: "Please wait", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // Upload image
        uploadImage { [weak self] result in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let url):
                        self?.showQRCode(for: url)
                    case .failure(let error):
                        self?.showError(error)
                    }
                }
            }
        }
    }

    private func uploadImage(completion: @escaping (Result<String, Error>) -> Void) {
        let uploadURL = URL(string: "https://picpopphotos.com")!
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
            return
        }
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool,
               success,
               let url = json["url"] as? String {
                completion(.success(url))
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
            }
        }.resume()
    }

    private func showQRCode(for url: String) {
        let qrVC = UIViewController()
        qrVC.view.backgroundColor = .clear
        qrVC.modalPresentationStyle = .formSheet
        qrVC.preferredContentSize = CGSize(width: 350, height: 450)
        
        // Create QR code
        let qrGenerator = CIFilter.qrCodeGenerator()
        qrGenerator.setValue(url.data(using: .utf8), forKey: "inputMessage")
        
        guard let qrImage = qrGenerator.outputImage else {
            showError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate QR code"]))
            return
        }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledQRImage = qrImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledQRImage, from: scaledQRImage.extent) else {
            showError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate QR code"]))
            return
        }
        
        // Main container for all content
        let mainContainer = UIView()
        mainContainer.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        mainContainer.layer.cornerRadius = 25
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        qrVC.view.addSubview(mainContainer)
        
        // QR code container
        let qrContainer = UIView()
        qrContainer.backgroundColor = .white
        qrContainer.layer.cornerRadius = 20
        qrContainer.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(qrContainer)
        
        let imageView = UIImageView(image: UIImage(cgImage: cgImage))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        qrContainer.addSubview(imageView)
        
        let titleLabel = UILabel()
        titleLabel.text = "Scan QR Code"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(titleLabel)
        
        let instructionsLabel = UILabel()
        instructionsLabel.text = "Use your phone's camera to scan"
        instructionsLabel.font = .systemFont(ofSize: 16)
        instructionsLabel.textColor = .lightGray
        instructionsLabel.textAlignment = .center
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(instructionsLabel)
        
        NSLayoutConstraint.activate([
            mainContainer.centerXAnchor.constraint(equalTo: qrVC.view.centerXAnchor),
            mainContainer.centerYAnchor.constraint(equalTo: qrVC.view.centerYAnchor),
            mainContainer.widthAnchor.constraint(equalToConstant: 300),
            mainContainer.heightAnchor.constraint(equalToConstant: 400),
            
            titleLabel.topAnchor.constraint(equalTo: mainContainer.topAnchor, constant: 25),
            titleLabel.centerXAnchor.constraint(equalTo: mainContainer.centerXAnchor),
            
            qrContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 25),
            qrContainer.centerXAnchor.constraint(equalTo: mainContainer.centerXAnchor),
            qrContainer.widthAnchor.constraint(equalToConstant: 250),
            qrContainer.heightAnchor.constraint(equalToConstant: 250),
            
            imageView.topAnchor.constraint(equalTo: qrContainer.topAnchor, constant: 15),
            imageView.leadingAnchor.constraint(equalTo: qrContainer.leadingAnchor, constant: 15),
            imageView.trailingAnchor.constraint(equalTo: qrContainer.trailingAnchor, constant: -15),
            imageView.bottomAnchor.constraint(equalTo: qrContainer.bottomAnchor, constant: -15),
            
            instructionsLabel.topAnchor.constraint(equalTo: qrContainer.bottomAnchor, constant: 25),
            instructionsLabel.centerXAnchor.constraint(equalTo: mainContainer.centerXAnchor)
        ])
        
        // Add tap gesture to QR view to reset timer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(userDidInteract))
        qrVC.view.addGestureRecognizer(tapGesture)
        
        activeQRViewController = qrVC
        present(qrVC, animated: true)
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Upload Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // Add these new methods for button highlighting
    @objc private func buttonTouchDown(_ sender: UIButton) {
        userDidInteract()
        UIView.animate(withDuration: 0.1) {
            sender.alpha = 0.7
        }
    }

    @objc private func buttonTouchUp(_ sender: UIButton) {
        userDidInteract()
        UIView.animate(withDuration: 0.1) {
            sender.alpha = 1.0
        }
    }

    // Add these new methods for inactivity timer
    private func startInactivityTimer() {
        stopInactivityTimer() // Stop existing timer if any
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: inactivityTimeout, repeats: false) { [weak self] _ in
            self?.dismissDueToInactivity()
        }
    }
    
    private func stopInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
    
    private func dismissDueToInactivity() {
        // First dismiss any presented view controllers (QR code, Print, AirDrop)
        if let presentedVC = presentedViewController {
            presentedVC.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                self.dismissMainPreview()
            }
        } else {
            dismissMainPreview()
        }
    }
    
    private func dismissMainPreview() {
        // Handle the main preview dismissal
        if let containerView = view.superview,
           let blurView = containerView.subviews.first(where: { $0 is UIVisualEffectView }) {
            // Fade out blur first
            UIView.animate(withDuration: 0.2, animations: {
                blurView.alpha = 0
            }) { _ in
                // Then dismiss with animation (slides down)
                self.onDismiss?()
                self.dismiss(animated: true)
            }
        } else {
            // Fallback if blur view not found
            onDismiss?()
            dismiss(animated: true)
        }
    }
    
    @objc public func userDidInteract() {
        startInactivityTimer() // Reset timer on any interaction
    }

    // Override present to track user interaction for any presented view controllers
    override public func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        userDidInteract()
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    @objc private func closeButtonPressed() {
        // Find the blur view in our parent container
        if let containerView = view.superview,
           let blurView = containerView.subviews.first(where: { $0 is UIVisualEffectView }) {
            // First fade out the blur
            UIView.animate(withDuration: 0.2, animations: {
                blurView.alpha = 0
            }) { _ in
                // Then dismiss with animation (slides down)
                self.onDismiss?()
                self.dismiss(animated: true)
            }
        } else {
            // Fallback if blur view not found
            onDismiss?()
            dismiss(animated: true)
        }
    }

    private func setupGradientCopyrightLabel() -> UILabel {
        let copyrightLabel = UILabel()
        copyrightLabel.text = "© PicPop"
        copyrightLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        copyrightLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create gradient layer
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.53, green: 0.44, blue: 0.95, alpha: 1).cgColor,  // Purple
            UIColor(red: 0.98, green: 0.45, blue: 0.45, alpha: 1).cgColor   // Pink-Orange
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        
        // Make label act as mask for gradient
        let textLayer = CATextLayer()
        textLayer.string = copyrightLabel.text
        textLayer.font = copyrightLabel.font
        textLayer.fontSize = copyrightLabel.font.pointSize
        textLayer.foregroundColor = UIColor.white.cgColor
        
        // Size the gradient to fit the text
        let textSize = copyrightLabel.text?.size(withAttributes: [.font: copyrightLabel.font!]) ?? .zero
        gradientLayer.frame = CGRect(origin: .zero, size: textSize)
        textLayer.frame = gradientLayer.frame
        
        gradientLayer.mask = textLayer
        copyrightLabel.layer.addSublayer(gradientLayer)
        
        return copyrightLabel
    }
}

// Add helper extension for button layout
extension UIButton {
    func centerImageAndButton(spacing: CGFloat = 6.0) {
        guard let imageSize = imageView?.image?.size,
              let titleLabel = titleLabel,
              let titleText = titleLabel.text else { return }
        
        let titleSize = titleText.size(withAttributes: [
            NSAttributedString.Key.font: titleLabel.font as Any
        ])
        
        let totalHeight = imageSize.height + spacing + titleSize.height
        
        imageEdgeInsets = UIEdgeInsets(
            top: -(totalHeight - imageSize.height),
            left: 0,
            bottom: 0,
            right: -titleSize.width
        )
        
        titleEdgeInsets = UIEdgeInsets(
            top: 0,
            left: -imageSize.width,
            bottom: -(totalHeight - titleSize.height),
            right: 0
        )
    }
}

extension NSLayoutConstraint {
    func with(priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
