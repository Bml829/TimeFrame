//
//  AddPhotoToChallengeViewController.swift
//  TimeFrame
//
//  Created by Megan Sundheim on 3/16/24.
//
// Project: TimeFrame
// EID: mas23586
// Course: CS371L

import UIKit
import AVFoundation
import FirebaseFirestore
import FirebaseStorage

class AddPhotoToChallengeViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var previewView: UIImageView!
    @IBOutlet weak var locationLabel: UILabel!
    
    var overlayView: UIView!
    var picker = UIImagePickerController()
    var cameraLoaded = false
    var currentCameraPosition: Int!
    var challenge: Challenge!
    let db = Firestore.firestore()
    let storage = Storage.storage()

    override func viewDidLoad() {
        super.viewDidLoad()
        picker.delegate = self
        setCustomBackImage()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        locationLabel.text = self.challenge.name
        if !cameraLoaded {
            // Only load the camera once automatically.
            showCamera()
        } else if previewView.image == nil {
            dismiss(animated: true)
        }
    }
    
    func showCamera() {
        // Check availability of camera.
        if UIImagePickerController.availableCaptureModes(for: .rear) != nil {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) {
                    accessGranted in guard accessGranted == true
                    else {return}
                }
            case .authorized:
                break
            default:
                print("Access denied.")
                dismiss(animated: true)
                return
            }
            
            cameraLoaded = true
            picker.sourceType = .camera
            picker.showsCameraControls = false
            currentCameraPosition = picker.cameraDevice.rawValue
            picker.allowsEditing = false 
            picker.cameraCaptureMode = .photo
            picker.cameraFlashMode = .off
            
            // Set overlay for camera.
            let translation = CGAffineTransformMakeTranslation(0.0, 123)
            picker.cameraViewTransform = translation
            overlayView = createOverlayView()
            picker.cameraOverlayView = overlayView
            
            self.present(picker, animated: true, completion: nil)
        } else {
            // Not available, pop up an alert.
            let alertVC = UIAlertController(title: "No Camera Available", message: "Sorry, this device does not have a camera.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                self.dismiss(animated: true)
            }
            alertVC.addAction(okAction)
            present(alertVC, animated: true)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let chosenImage = info[.originalImage] as? UIImage {
            var imageToShow = chosenImage
            if currentCameraPosition == UIImagePickerController.CameraDevice.front.rawValue {
                // Prevent flipping of front-facing photos.
                imageToShow = chosenImage.flipHorizontally()!
            }
            
            // Shrink to visible size.
            previewView.contentMode = .scaleAspectFit
            
            // Put the image in the imageView.
            previewView.image = imageToShow
        }
 
        // Dismiss this popover.
        dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
    
    @IBAction func onSubmitButtonPressed(_ sender: Any) {
        let challengeImage = ChallengeImage(image: previewView.image!, numViews: 1, numLikes: 0, numFlags: 0, hidden: false, capturedTimestamp: .now)
        
        // Add photo to challenge album in Firestore.
        let photoRef = db.collection("geochallenges").document(self.challenge.challengeID).collection("album").addDocument(data: [:]) { [weak self] (error) in
            if let error = error {
                print("Error adding document: \(error.localizedDescription)")
            }
        }
        
        let storageRef = storage.reference().child("geochallenges")
        let albumRef = storageRef.child(self.challenge.challengeID + "/" + photoRef.documentID)

        if let imageData = previewView.image!.jpegData(compressionQuality: 0.5) {
            albumRef.putData(imageData, metadata: nil) { (metadata, error) in
                if let error = error {
                    print("Error uploading image to Firebase Storage: \(error.localizedDescription)")
                } else {
                    albumRef.downloadURL { (url, error) in
                        if let downloadURL = url?.absoluteString {
                            challengeImage.url = downloadURL
                            challengeImage.documentID = photoRef.documentID
                            self.saveImageUrlToFirestore(downloadURL: downloadURL, albumName: self.challenge.challengeID, photoID: photoRef.documentID, challengeImage: challengeImage)
                        }
                    }
                }
            }
        }
        
        challenge.addChallengeImage(challengeImage: challengeImage)
        dismiss(animated: true)
    }
    
    func saveImageUrlToFirestore(downloadURL: String, albumName: String, photoID: String, challengeImage: ChallengeImage) {
        db.collection("geochallenges").document(albumName).collection("album").document(photoID).setData(["url": downloadURL, "numViews": 1, "numLikes": 0, "numFlags": 0, "hidden": false, "capturedTimestamp": Timestamp(date: challengeImage.capturedTimestamp)]) { [weak self] (error) in
            if let error = error {
                print("Error adding document: \(error.localizedDescription)")
            } else {
                print("Document added successfully")
            }
        }
    }
    
    @IBAction func onBackButtonPressed(_ sender: Any) {
        dismiss(animated: true)
    }
    
    func createOverlayView() -> UIView {
        // Create container view for overlay elements.
        var containerView = UIView(frame: UIScreen.main.bounds)
        containerView.backgroundColor = .clear
        
        // Add top and bottom rectangles of overlay.
        var topRect = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 123))
        topRect.backgroundColor = .black
        containerView.addSubview(topRect)
        
        var bottomRect = UIView(frame: CGRect(x: 0, y: 643, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.maxY - 643))
        bottomRect.backgroundColor = .black
        containerView.addSubview(bottomRect)
        
        // Add image overlay to camera preview.
        var imageOverlay = UIImageView(frame: CGRect(x: 0, y: 123, width: UIScreen.main.bounds.width, height: 643 - 123))
        
        // Display initial image as overlay.
        imageOverlay.image = self.challenge.album[self.challenge.album.count - 1].image
        imageOverlay.contentMode = .scaleAspectFill
        imageOverlay.alpha = 0.4
        containerView.addSubview(imageOverlay)
        
        // Add buttons to overlay.
        var captureButton = UIButton(frame: CGRect(x: 146, y: 643 + 46, width: 100, height: 100))
        let captureConfig = UIImage.SymbolConfiguration(pointSize: 80, weight: .regular)
        var captureImage = UIImage(systemName: "button.programmable", withConfiguration: captureConfig)
        captureButton.setImage(captureImage, for: .normal)
        captureButton.tintColor = .white
        captureButton.addTarget(self, action: #selector(onCaptureButtonPressed), for: .touchUpInside)
        containerView.addSubview(captureButton)
        
        var flipButton = UIButton(frame: CGRect(x: 325, y: 643 + 71, width: 48, height: 48))
        let flipConfig = UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)
        var flipImage = UIImage(systemName: "arrow.triangle.2.circlepath", withConfiguration: flipConfig)
        flipButton.setImage(flipImage, for: .normal)
        flipButton.tintColor = .white
        var tintConfig = UIButton.Configuration.tinted()
        tintConfig.cornerStyle = .capsule
        flipButton.configuration = tintConfig
        flipButton.addTarget(self, action: #selector(onFlipButtonPressed), for: .touchUpInside)
        containerView.addSubview(flipButton)
        
        var cancelButton = UIButton(frame: CGRect(x: 8, y: 643 + 78, width: 81, height: 35))
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(onCancelButtonPressed), for: .touchUpInside)
        containerView.addSubview(cancelButton)
        
        return containerView
    }
    
    // Capture photo.
    @objc func onCaptureButtonPressed() {
        picker.takePicture()
    }
    
    // Flip the camera.
    @objc func onFlipButtonPressed() {
        if currentCameraPosition == UIImagePickerController.CameraDevice.rear.rawValue {
            // Flip to front camera.
            picker.cameraDevice = UIImagePickerController.CameraDevice.front
            currentCameraPosition = picker.cameraDevice.rawValue
        } else if currentCameraPosition == UIImagePickerController.CameraDevice.front.rawValue {
            // Flip to rear camera.
            picker.cameraDevice = UIImagePickerController.CameraDevice.rear
            currentCameraPosition = picker.cameraDevice.rawValue
        }
    }
    
    // Dismiss popover.
    @objc func onCancelButtonPressed() {
        dismiss(animated: true)
    }
    
    // Retake photo.
    @IBAction func onRetakeButtonPressed(_ sender: Any) {
        showCamera()
    }
    
    @IBAction func onShareButtonPressed(_ sender: Any) {
        let image = previewView.image
        
        // Set up activity view controller.
        let imageToShare = [ image! ]
        let activityViewController = UIActivityViewController(activityItems: imageToShare, applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view
        
        self.present(activityViewController, animated: true, completion: nil)
    }
}

// By Josh Bernfeld (https://stackoverflow.com/questions/24965638/how-to-flip-uiimage-horizontally-with-swift).
extension UIImage {
    func flipHorizontally() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        context.translateBy(x: self.size.width/2, y: self.size.height/2)
        context.scaleBy(x: -1.0, y: 1.0)
        context.translateBy(x: -self.size.width/2, y: -self.size.height/2)
        
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}
