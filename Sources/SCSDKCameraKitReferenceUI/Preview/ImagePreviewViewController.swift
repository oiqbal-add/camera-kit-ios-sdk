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
        super.viewDidLoad()
        modalPresentationStyle = .overFullScreen
        setupUI()
    }

    // MARK: Setup

    private func setupUI() {
        view.insertSubview(imageView, at: 0)
        
        let bottomAnchor = view.safeAreaLayoutGuide.bottomAnchor
        
        // Create bottom bar background first
        let bottomBarBackground = UIView()
        bottomBarBackground.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        bottomBarBackground.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(bottomBarBackground, at: 1)
        
        NSLayoutConstraint.activate([
            bottomBarBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBarBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBarBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBarBackground.heightAnchor.constraint(equalToConstant: 140)
        ])
        
        // Setup image view with proper aspect ratio
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            imageView.bottomAnchor.constraint(equalTo: bottomBarBackground.topAnchor, constant: -20)
        ])
        
        // Clear existing buttons
        bottomButtonStackView.subviews.forEach { $0.removeFromSuperview() }
        
        // Configure buttons
        let buttonConfigs: [(String, String)] = [
            ("AirDrop", "square.and.arrow.up.fill"),
            ("Print", "printer.fill"),
            ("QR Code", "qrcode")
        ]
        
        buttonConfigs.forEach { (title, iconName) in
            // Create container stack view for each button
            let buttonStack = UIStackView()
            buttonStack.axis = .vertical
            buttonStack.alignment = .center
            buttonStack.spacing = 8
            buttonStack.translatesAutoresizingMaskIntoConstraints = false
            
            // Create and configure icon
            let iconConfig = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
            let icon = UIImage(systemName: iconName, withConfiguration: iconConfig)
            
            let iconView = UIImageView(image: icon)
            iconView.contentMode = .scaleAspectFit
            iconView.tintColor = .white
            
            // Create and configure label
            let label = UILabel()
            label.text = title
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = .white
            label.textAlignment = .center
            
            // Add views to stack
            buttonStack.addArrangedSubview(iconView)
            buttonStack.addArrangedSubview(label)
            
            // Create button that covers the entire stack
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            
            // Wrap stack view in a container with the button
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(buttonStack)
            container.addSubview(button)
            
            // Set constraints
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: 32),
                iconView.heightAnchor.constraint(equalToConstant: 32),
                
                buttonStack.topAnchor.constraint(equalTo: container.topAnchor),
                buttonStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                buttonStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                
                button.topAnchor.constraint(equalTo: container.topAnchor),
                button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                
                container.widthAnchor.constraint(equalToConstant: 80),
                container.heightAnchor.constraint(equalToConstant: 80)
            ])
            
            // Add tap handler
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
            
            // Add highlight effect
            button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
            
            // Add to main stack view
            bottomButtonStackView.addArrangedSubview(container)
        }
        
        // Configure main stack view
        bottomButtonStackView.spacing = 50
        bottomButtonStackView.distribution = .equalSpacing
        bottomButtonStackView.alignment = .center
        
        NSLayoutConstraint.activate([
            bottomButtonStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomButtonStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -30),
            bottomButtonStackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            bottomButtonStackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            bottomButtonStackView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        view.backgroundColor = .black
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
        snapchatDelegate?.cameraKitViewController(self, openSnapchat: .photo(image))
    }

    override public func sharePreviewPressed(_ sender: UIButton) {
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

    override public func printButtonPressed(_ sender: UIButton) {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .photo
        printInfo.jobName = "Print Photo"
        
        printController.printInfo = printInfo
        printController.printingItem = image
        
        printController.present(animated: true) { _, _, error in
            if let error = error {
                print("Printing error: \(error.localizedDescription)")
            }
        }
    }

    override public func qrCodeButtonPressed(_ sender: UIButton) {
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Uploading...", message: "Please wait", preferredStyle: .alert)
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
        let uploadURL = URL(string: "https://image-upload-worker.glxss.workers.dev")!
        
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
        
        print("Attempting upload to: \(uploadURL.absoluteString)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Log response for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("Response status code: \(httpResponse.statusCode)")
                print("Response headers: \(httpResponse.allHeaderFields)")
            }
            
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let data = data {
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("Response data: \(responseString)")
                
                // Parse the response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool,
                   success,
                   let url = json["url"] as? String {
                    print("Successfully got URL: \(url)")
                    completion(.success(url))
                    return
                }
                
                completion(.failure(NSError(domain: "", code: -1, 
                    userInfo: [NSLocalizedDescriptionKey: "Invalid server response: \(responseString)"])))
            }
        }.resume()
    }
    
    private func showQRCode(for url: String) {
        let qrVC = UIViewController()
        qrVC.view.backgroundColor = .black
        qrVC.modalPresentationStyle = .formSheet
        qrVC.preferredContentSize = CGSize(width: 350, height: 450) // Fixed size for better presentation
        
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
        mainContainer.backgroundColor = UIColor(white: 0.1, alpha: 1.0) // Dark gray background
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
        
        // Layout
        NSLayoutConstraint.activate([
            // Main container
            mainContainer.centerXAnchor.constraint(equalTo: qrVC.view.centerXAnchor),
            mainContainer.centerYAnchor.constraint(equalTo: qrVC.view.centerYAnchor),
            mainContainer.widthAnchor.constraint(equalToConstant: 300),
            mainContainer.heightAnchor.constraint(equalToConstant: 400),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: mainContainer.topAnchor, constant: 25),
            titleLabel.centerXAnchor.constraint(equalTo: mainContainer.centerXAnchor),
            
            // QR Container
            qrContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 25),
            qrContainer.centerXAnchor.constraint(equalTo: mainContainer.centerXAnchor),
            qrContainer.widthAnchor.constraint(equalToConstant: 250),
            qrContainer.heightAnchor.constraint(equalToConstant: 250),
            
            // QR Image
            imageView.topAnchor.constraint(equalTo: qrContainer.topAnchor, constant: 15),
            imageView.leadingAnchor.constraint(equalTo: qrContainer.leadingAnchor, constant: 15),
            imageView.trailingAnchor.constraint(equalTo: qrContainer.trailingAnchor, constant: -15),
            imageView.bottomAnchor.constraint(equalTo: qrContainer.bottomAnchor, constant: -15),
            
            // Instructions
            instructionsLabel.topAnchor.constraint(equalTo: qrContainer.bottomAnchor, constant: 25),
            instructionsLabel.centerXAnchor.constraint(equalTo: mainContainer.centerXAnchor)
        ])
        
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
        UIView.animate(withDuration: 0.1) {
            sender.alpha = 0.7
        }
    }

    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.alpha = 1.0
        }
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
