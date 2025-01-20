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
        
        NSLayoutConstraint.activate([
            // Keep small top padding, increase bottom padding for buttons
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            // Make bottom padding much larger (from 60 to 120) for buttons
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -120)
        ])
        
        imageView.contentMode = .scaleAspectFit
        view.backgroundColor = .black
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
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
            return
        }
        
        let url = URL(string: "https://image-upload-worker.glxss.workers.dev")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
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
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let url = json["url"] as? String else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                return
            }
            
            completion(.success(url))
        }.resume()
    }
    
    private func showQRCode(for url: String) {
        let qrGenerator = CIFilter.qrCodeGenerator()
        
        // Safely unwrap the message data
        guard let messageData = url.data(using: .utf8) else {
            showError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate QR code"]))
            return
        }
        
        qrGenerator.setValue(messageData, forKey: "inputMessage")
        
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
        
        let qrUIImage = UIImage(cgImage: cgImage)
        
        // Create and show QR code view
        let qrAlert = UIAlertController(title: "Scan QR Code", message: "Scan this code to view the image", preferredStyle: .alert)
        
        // Add QR code image view
        let imageView = UIImageView(image: qrUIImage)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        qrAlert.view.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: qrAlert.view.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: qrAlert.view.topAnchor, constant: 60),
            imageView.widthAnchor.constraint(equalToConstant: 200),
            imageView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        // Make alert taller to accommodate QR code
        qrAlert.view.heightAnchor.constraint(equalToConstant: 320).isActive = true
        
        qrAlert.addAction(UIAlertAction(title: "Done", style: .default))
        present(qrAlert, animated: true)
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
