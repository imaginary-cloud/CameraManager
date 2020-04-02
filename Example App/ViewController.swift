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
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var flashModeImageView: UIImageView!
    @IBOutlet weak var outputImageView: UIImageView!
    @IBOutlet weak var cameraTypeImageView: UIImageView!
    @IBOutlet weak var qualityLabel: UILabel!
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var askForPermissionsLabel: UILabel!
    
    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var locationButton: UIButton!
    
    let darkBlue = UIColor(red: 4/255, green: 14/255, blue: 26/255, alpha: 1)
    let lightBlue = UIColor(red: 24/255, green: 125/255, blue: 251/255, alpha: 1)
    let redColor = UIColor(red: 229/255, green: 77/255, blue: 67/255, alpha: 1)
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //      cameraManager.shouldRespondToOrientationChanges = false
        cameraManager.shouldEnableExposure = true
        
        cameraManager.shouldFlipFrontCameraImage = false
        cameraManager.showAccessPermissionPopupAutomatically = false
        navigationController?.navigationBar.isHidden = true
        
        askForPermissionsLabel.isHidden = true
        askForPermissionsLabel.backgroundColor = lightBlue
        askForPermissionsLabel.textColor = .white
        askForPermissionsLabel.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(askForCameraPermissions))
        askForPermissionsLabel.addGestureRecognizer(tapGesture)
        
        footerView.backgroundColor = darkBlue
        headerView.backgroundColor = darkBlue
        
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
        } else {
            askForPermissionsLabel.isHidden = false
        }
        
        flashModeImageView.image = UIImage(named: "flash_off")
        if cameraManager.hasFlash {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(changeFlashMode))
            flashModeImageView.addGestureRecognizer(tapGesture)
        }
        
        outputImageView.image = UIImage(named: "output_video")
        let outputGesture = UITapGestureRecognizer(target: self, action: #selector(outputModeButtonTapped))
        outputImageView.addGestureRecognizer(outputGesture)
        
        cameraTypeImageView.image = UIImage(named: "switch_camera")
        let cameraTypeGesture = UITapGestureRecognizer(target: self, action: #selector(changeCameraDevice))
        cameraTypeImageView.addGestureRecognizer(cameraTypeGesture)
        
        qualityLabel.isUserInteractionEnabled = true
        let qualityGesture = UITapGestureRecognizer(target: self, action: #selector(changeCameraQuality))
        qualityLabel.addGestureRecognizer(qualityGesture)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.isHidden = true
        cameraManager.resumeCaptureSession()
        cameraManager.startQRCodeDetection { (result) in
            switch result {
            case .success(let value):
                print(value)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraManager.stopQRCodeDetection()
        cameraManager.stopCaptureSession()
    }
    
    
    // MARK: - ViewController
    fileprivate func addCameraToView()
    {
        cameraManager.addPreviewLayerToView(cameraView, newCameraOutputMode: CameraOutputMode.videoWithMic)
        cameraManager.showErrorBlock = { [weak self] (erTitle: String, erMessage: String) -> Void in
            
            let alertController = UIAlertController(title: erTitle, message: erMessage, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { (alertAction) -> Void in  }))
            
            self?.present(alertController, animated: true, completion: nil)
        }
    }
    
    // MARK: - @IBActions
    
    @IBAction func changeFlashMode(_ sender: UIButton) {
        
        switch cameraManager.changeFlashMode() {
        case .off:
            flashModeImageView.image = UIImage(named: "flash_off")
        case .on:
            flashModeImageView.image = UIImage(named: "flash_on")
        case .auto:
            flashModeImageView.image = UIImage(named: "flash_auto")
        }
    }
    
    @IBAction func recordButtonTapped(_ sender: UIButton) {
        
        switch cameraManager.cameraOutputMode {
        case .stillImage:
            cameraManager.capturePictureWithCompletion({ result in
                switch result {
                case .failure:
                    self.cameraManager.showErrorBlock("Error occurred", "Cannot save picture.")
                case .success(let content):
                    
                    let vc: ImageViewController? = self.storyboard?.instantiateViewController(withIdentifier: "ImageVC") as? ImageViewController
                    if let validVC: ImageViewController = vc,
                        case let capturedImage = content.asImage {
                        validVC.image = capturedImage
                        validVC.cameraManager = self.cameraManager
                        self.navigationController?.pushViewController(validVC, animated: true)
                    }
                }
            })
        case .videoWithMic, .videoOnly:
            cameraButton.isSelected = !cameraButton.isSelected
            cameraButton.setTitle("", for: UIControl.State.selected)
            
            cameraButton.backgroundColor = cameraButton.isSelected ? redColor : lightBlue
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
    
    
    
    @IBAction func locateMeButtonTapped(_ sender: Any) {
        cameraManager.shouldUseLocationServices = true
        locationButton.isHidden = true
    }
    
    @IBAction func outputModeButtonTapped(_ sender: UIButton) {
        
        cameraManager.cameraOutputMode = cameraManager.cameraOutputMode == CameraOutputMode.videoWithMic ? CameraOutputMode.stillImage : CameraOutputMode.videoWithMic
        switch cameraManager.cameraOutputMode {
        case .stillImage:
            cameraButton.isSelected = false
            cameraButton.backgroundColor = lightBlue
            outputImageView.image = UIImage(named: "output_image")
        case .videoWithMic, .videoOnly:
            outputImageView.image = UIImage(named: "output_video")
        }
    }
    
    @IBAction func changeCameraDevice() {
        cameraManager.cameraDevice = cameraManager.cameraDevice == CameraDevice.front ? CameraDevice.back : CameraDevice.front
    }
    
    @IBAction func askForCameraPermissions() {
        
        self.cameraManager.askUserForCameraPermission({ permissionGranted in
            
            if permissionGranted {
                self.askForPermissionsLabel.isHidden = true
                self.askForPermissionsLabel.alpha = 0
                self.addCameraToView()
            } else {
                if #available(iOS 10.0, *) { 
                    UIApplication.shared.open(URL(string:UIApplication.openSettingsURLString)!)
                } else {
                    // Fallback on earlier versions
                }
            }
        })
    }
    
    @IBAction func changeCameraQuality() {
        
        switch cameraManager.changeQualityMode() {
        case .high:
            qualityLabel.text = "High"
        case .low:
            qualityLabel.text = "Low"
        case .medium:
            qualityLabel.text = "Medium"
        }
    }
}


