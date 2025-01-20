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
        setup()
    }

    // MARK: Setup

    private func setup() {
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
            bottomBarBackground.heightAnchor.constraint(equalToConstant: 120)
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
        
        // Style buttons
        let buttons = [(shareButton, "Share"), (printButton, "Print"), (qrCodeButton, "QR Code")]
        buttons.forEach { (button, title) in
            // Remove background and border
            button.backgroundColor = .clear
            
            // Make icons much bigger
            if let imageView = button.imageView {
                imageView.contentMode = .scaleAspectFit
                button.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 30, right: 10)
            }
            
            // Configure title
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
            button.setTitleColor(.white, for: .normal)
            button.titleEdgeInsets = UIEdgeInsets(top: 60, left: -60, bottom: 0, right: 0)
            
            // Make button bigger
            button.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        }
        
        // Update button stack view constraints
        bottomButtonStackView.spacing = 100 // Increase spacing between buttons
        NSLayoutConstraint.activate([
            bottomButtonStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomButtonStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            bottomButtonStackView.heightAnchor.constraint(equalToConstant: 100)
        ])
        
        view.backgroundColor = .black
    }

    @objc private func handleHover(_ gesture: UIHoverGestureRecognizer) {
        guard let button = gesture.view as? UIButton else { return }
        
        UIView.animate(withDuration: 0.3) {
            switch gesture.state {
            case .began, .changed:
                button.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                button.backgroundColor = UIColor(white: 1, alpha: 0.25)
            case .ended:
                button.transform = .identity
                button.backgroundColor = UIColor(white: 1, alpha: 0.15)
            default:
                break
            }
        }
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

    override public func savePreviewPressed(_ sender: UIButton) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: self.image)
        }) { saved, error in
            var title: String
            var message: String
            if saved {
                title = "Save Success"
                message = "Successfully saved photo to library"
            } else {
                title = "Save Failure"
                message = "Failed to save photo to library"
                print("failed to save video with error: \(error?.localizedDescription ?? "no error")")
            }

            DispatchQueue.main.async {
                let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(action)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
}
