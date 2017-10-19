//
//  ViewController.swift
//  camera
//
//  Created by Natalia Terlecka on 10/10/14.
//  Copyright (c) 2014 imaginaryCloud. All rights reserved.
//

import UIKit
import CameraManager

class ViewController: UIViewController {
    
    // MARK: - Constants

    let cameraManager = CameraManager()
    
    // MARK: - @IBOutlets

    @IBOutlet weak var cameraView: UIView!
    
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var flashModeButton: UIButton!
    
    @IBOutlet weak var askForPermissionsButton: UIButton!
    @IBOutlet weak var askForPermissionsLabel: UILabel!
    
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cameraManager.showAccessPermissionPopupAutomatically = false
        
        askForPermissionsButton.isHidden = true
        askForPermissionsLabel.isHidden = true

        let currentCameraState = cameraManager.currentCameraStatus()
        
        if currentCameraState == .notDetermined {
            askForPermissionsButton.isHidden = false
            askForPermissionsLabel.isHidden = false
        } else if (currentCameraState == .ready) {
            addCameraToView()
        }
        if !cameraManager.hasFlash {
            flashModeButton.isEnabled = false
            flashModeButton.setTitle("No flash", for: .normal)
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.isHidden = true
        cameraManager.resumeCaptureSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraManager.stopCaptureSession()
    }
    
    
    // MARK: - ViewController
    
    private func addCameraToView()
    {
        cameraManager.addPreviewLayerToView(cameraView, newCameraOutputMode: .videoWithMic)
        cameraManager.showErrorBlock = { [weak self] (erTitle: String, erMessage: String) -> Void in
        
            let alertController = UIAlertController(title: erTitle, message: erMessage, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (alertAction) -> Void in  }))
            
            self?.present(alertController, animated: true, completion: nil)
        }
    }

    // MARK: - @IBActions

    @IBAction func changeFlashMode(sender: UIButton)
    {
        switch (cameraManager.changeFlashMode()) {
        case .off:
            sender.setTitle("Flash Off", for: .normal)
        case .on:
            sender.setTitle("Flash On", for: .normal)
        case .auto:
            sender.setTitle("Flash Auto", for: .normal)
        }
    }
    
    @IBAction func recordButtonTapped(sender: UIButton) {
        
        switch (cameraManager.cameraOutputMode) {
        case .stillImage:
            cameraManager.capturePictureWithCompletion { (image, error) -> Void in
                if let errorOccured = error {
                    self.cameraManager.showErrorBlock("Error occurred", errorOccured.localizedDescription)
                }
                else {
                    let vc: ImageViewController? = self.storyboard?.instantiateViewController(withIdentifier: "ImageVC") as? ImageViewController
                    if let validVC: ImageViewController = vc {
                        if let capturedImage = image {
                            validVC.image = capturedImage
                            self.navigationController?.pushViewController(validVC, animated: true)
                        }
                    }
                }
            }
        case .videoWithMic, .videoOnly:
            sender.isSelected = !sender.isSelected
            sender.setTitle(" ", for: .selected)
            sender.backgroundColor = sender.isSelected ? UIColor.red : UIColor.green
            if sender.isSelected {
                cameraManager.startRecordingVideo()
            } else {
                cameraManager.stopVideoRecording { (videoURL, error) -> Void in
                    if let errorOccured = error {                        
                        self.cameraManager.showErrorBlock("Error occurred", errorOccured.localizedDescription)
                    }
                }
            }
        }
    }
    
    @IBAction func outputModeButtonTapped(sender: UIButton) {
        
        cameraManager.cameraOutputMode = cameraManager.cameraOutputMode == .videoWithMic ? .stillImage : .videoWithMic
        switch (cameraManager.cameraOutputMode) {
        case .stillImage:
            cameraButton.isSelected = false
            cameraButton.backgroundColor = UIColor.green
            sender.setTitle("Image", for: .normal)
        case .videoWithMic, .videoOnly:
            sender.setTitle("Video", for: .normal)
        }
    }
    
    @IBAction func changeCameraDevice(sender: UIButton) {
        
        cameraManager.cameraDevice = cameraManager.cameraDevice == .front ? .back : .front
        switch (cameraManager.cameraDevice) {
        case .front:
            sender.setTitle("Front", for: .normal)
        case .back:
            sender.setTitle("Back", for: .normal)
        }
    }
    
    @IBAction func askForCameraPermissions(sender: UIButton) {
        
        cameraManager.askUserForCameraPermission { permissionGranted in
            self.askForPermissionsButton.isHidden = true
            self.askForPermissionsLabel.isHidden = true
            self.askForPermissionsButton.alpha = 0
            self.askForPermissionsLabel.alpha = 0
            if permissionGranted {
                self.addCameraToView()
            }
        }
    }
    
    @IBAction func changeCameraQuality(sender: UIButton) {
        
        switch (cameraManager.changeQualityMode()) {
        case .high:
            sender.setTitle("High", for: .normal)
        case .low:
            sender.setTitle("Low", for: .normal)
        case .medium:
            sender.setTitle("Medium", for: .normal)
        }
    }
}


