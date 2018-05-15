//
//  ViewController.swift
//  camera
//
//  Created by Natalia Terlecka on 10/10/14.
//  Copyright (c) 2014 Imaginary Cloud. All rights reserved.
//

import UIKit
import CameraManager
import CoreLocation

class ViewController: UIViewController {
    
    // MARK: - Constants

    let cameraManager = CameraManager()
    
    // MARK: - @IBOutlets

    @IBOutlet weak var cameraView: UIView!
    
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var flashModeButton: UIButton!
    
    @IBOutlet weak var locationButton: UIButton!
    
    @IBOutlet weak var askForPermissionsLabel: UILabel!
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cameraManager.shouldFlipFrontCameraImage = false
        cameraManager.showAccessPermissionPopupAutomatically = false
        navigationController?.navigationBar.isHidden = true
        
        askForPermissionsLabel.isHidden = true
        
        askForPermissionsLabel.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(askForCameraPermissions))
        askForPermissionsLabel.addGestureRecognizer(tapGesture)
        
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .authorizedAlways, .authorizedWhenInUse:
                self.cameraManager.shouldUseLocationServices = true
                self.locationButton.isHidden = true
            default:
                self.cameraManager.shouldUseLocationServices = false
            }
        }

        let currentCameraState = cameraManager.currentCameraStatus()
        
        if currentCameraState == .notDetermined {
            askForPermissionsLabel.isHidden = false
        } else if currentCameraState == .ready {
            addCameraToView()
        }

        if !cameraManager.hasFlash {
            flashModeButton.isEnabled = false
            flashModeButton.setTitle("No flash", for: UIControlState())
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
    fileprivate func addCameraToView()
    {
        cameraManager.addPreviewLayerToView(cameraView, newCameraOutputMode: CameraOutputMode.videoWithMic)
        cameraManager.showErrorBlock = { [weak self] (erTitle: String, erMessage: String) -> Void in
        
            let alertController = UIAlertController(title: erTitle, message: erMessage, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (alertAction) -> Void in  }))
            
            self?.present(alertController, animated: true, completion: nil)
        }
    }

    // MARK: - @IBActions

    @IBAction func changeFlashMode(_ sender: UIButton)
    {
        switch (cameraManager.changeFlashMode()) {
        case .off:
            sender.setTitle("Flash Off", for: UIControlState())
        case .on:
            sender.setTitle("Flash On", for: UIControlState())
        case .auto:
            sender.setTitle("Flash Auto", for: UIControlState())
        }
    }
    
    @IBAction func recordButtonTapped(_ sender: UIButton) {
        
        switch (cameraManager.cameraOutputMode) {
        case .stillImage:
            cameraManager.capturePictureWithCompletion({ (image, error) -> Void in
                if error != nil {
                    self.cameraManager.showErrorBlock("Error occurred", "Cannot save picture.")
                }
                else {
                    let vc: ImageViewController? = self.storyboard?.instantiateViewController(withIdentifier: "ImageVC") as? ImageViewController
                    if let validVC: ImageViewController = vc,
                        let capturedImage = image {
                            validVC.image = capturedImage
                            validVC.cameraManager = self.cameraManager
                            self.navigationController?.pushViewController(validVC, animated: true)
                    }
                }
            })
        case .videoWithMic, .videoOnly:
            sender.isSelected = !sender.isSelected
            sender.setTitle(" ", for: UIControlState.selected)
            sender.backgroundColor = sender.isSelected ? UIColor.red : UIColor.green
            if sender.isSelected {
                cameraManager.startRecordingVideo()
            } else {
                cameraManager.stopVideoRecording({ (videoURL, error) -> Void in
                    if error != nil {
                        self.cameraManager.showErrorBlock("Error occurred", "Cannot save video.")
                    }
                })
            }
        }
    }
    
    @IBAction func outputModeButtonTapped(_ sender: UIButton) {
        
        cameraManager.cameraOutputMode = cameraManager.cameraOutputMode == CameraOutputMode.videoWithMic ? CameraOutputMode.stillImage : CameraOutputMode.videoWithMic
        switch (cameraManager.cameraOutputMode) {
        case .stillImage:
            cameraButton.isSelected = false
            cameraButton.backgroundColor = UIColor.green
            sender.setTitle("Image", for: UIControlState())
        case .videoWithMic, .videoOnly:
            sender.setTitle("Video", for: UIControlState())
        }
    }
    
    @IBAction func locateMeButtonTapped(_ sender: Any) {
        self.cameraManager.shouldUseLocationServices = true
        self.locationButton.isHidden = true
    }
    
    @IBAction func changeCameraDevice(_ sender: UIButton) {
        
        cameraManager.cameraDevice = cameraManager.cameraDevice == CameraDevice.front ? CameraDevice.back : CameraDevice.front
        switch (cameraManager.cameraDevice) {
        case .front:
            sender.setTitle("Front", for: UIControlState())
        case .back:
            sender.setTitle("Back", for: UIControlState())
        }
    }
    
    @IBAction func askForCameraPermissions(_ sender: UIButton) {
        
        cameraManager.askUserForCameraPermission({ permissionGranted in
            self.askForPermissionsLabel.isHidden = true
            self.askForPermissionsLabel.alpha = 0
            if permissionGranted {
                self.addCameraToView()
            }
        })
    }
    
    @IBAction func changeCameraQuality(_ sender: UIButton) {
        
        switch (cameraManager.changeQualityMode()) {
        case .high:
            sender.setTitle("High", for: UIControlState())
        case .low:
            sender.setTitle("Low", for: UIControlState())
        case .medium:
            sender.setTitle("Medium", for: UIControlState())
        }
    }
}


