//
//  CameraManager.swift
//  camera
//
//  Created by Natalia Terlecka on 10/10/14.
//  Copyright (c) 2014 imaginaryCloud. All rights reserved.
//

import UIKit
import AVFoundation

private let _singletonSharedInstance = CameraManager()

class CameraManager: NSObject {
   
    var captureSession: AVCaptureSession?
    var showErrorBlock:(erTitle: String, erMessage: String) -> Void = { (erTitle: String, erMessage: String) -> Void in
        UIAlertView(title: erTitle, message: erMessage, delegate: nil, cancelButtonTitle: "OK").show()
    }
    
    private var sessionQueue: dispatch_queue_t = dispatch_queue_create("CameraSessionQueue", DISPATCH_QUEUE_SERIAL)
    private var frontCamera: AVCaptureInput?
    private var rearCamera: AVCaptureInput?
    private var stillImageOutput: AVCaptureStillImageOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var cameraIsSetup = false
    private weak var embedingView: UIView?
    
    class var sharedInstance: CameraManager {
        return _singletonSharedInstance
    }
    
    deinit {
        self.stopCaptureSession()
        self._stopFollowingDeviceOrientation()
    }
    
    func addPreeviewLayerToView(view: UIView)
    {
        if self.cameraIsSetup {
            self._addPreeviewLayerToView(view)
        } else {
            self._setupCamera({ Void -> Void in
                self._addPreeviewLayerToView(view)
            })
        }
    }
    
    func stopCaptureSession()
    {
        self.captureSession?.stopRunning()
    }

    func capturePictureWithCompletition(imageCompletition: UIImage -> Void)
    {
        if self.cameraIsSetup {
            dispatch_async(self.sessionQueue, {
                if let validStillImageOutput = self.stillImageOutput? {
                    validStillImageOutput.captureStillImageAsynchronouslyFromConnection(validStillImageOutput.connectionWithMediaType(AVMediaTypeVideo), completionHandler: { [weak self] (sample: CMSampleBuffer!, error: NSError!) -> Void in
                        if (error? != nil) {
                            dispatch_async(dispatch_get_main_queue(), {
                                if let weakSelf = self {
                                    weakSelf._show("error", message: error.localizedDescription)
                                }
                            })
                        } else {
                            let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sample)
                            imageCompletition(UIImage(data: imageData))
                        }
                    })
                }
            })
        } else {
            self._show("No capture session setup", message: "I can't take any picture")
        }
    }
    
    func orientationChanged()
    {
        switch UIDevice.currentDevice().orientation {
        case .LandscapeLeft:
            self.previewLayer?.connection.videoOrientation = .LandscapeRight
        case .LandscapeRight:
            self.previewLayer?.connection.videoOrientation = .LandscapeLeft
        default:
            self.previewLayer?.connection.videoOrientation = .Portrait
        }
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            if let validEmbedingView = self.embedingView? {
                self.previewLayer?.frame = validEmbedingView.bounds
            }
        })
    }
    
    private func _setupCamera(completition: Void -> Void)
    {
        self._checkIfCameraIsAvailable()
        
        self.captureSession = AVCaptureSession()
        self.captureSession?.sessionPreset = AVCaptureSessionPresetPhoto

        dispatch_async(sessionQueue, {
            if let validCaptureSession = self.captureSession? {
                validCaptureSession.beginConfiguration()
                self._addVideoInput()
                self._addStillImageOutput()
                self._setupPreviewLayer()
                validCaptureSession.commitConfiguration()
                validCaptureSession.startRunning()
                self._startFollowingDeviceOrientation()
                completition()
                self.cameraIsSetup = true
            }
        })
    }
    
    private func _startFollowingDeviceOrientation()
    {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "orientationChanged", name: UIDeviceOrientationDidChangeNotification, object: nil)
    }
    
    private func _stopFollowingDeviceOrientation()
    {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
    }

    private func _addPreeviewLayerToView(view: UIView)
    {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.previewLayer?.frame = view.layer.bounds
            view.clipsToBounds = true
            view.layer.addSublayer(self.previewLayer)
            self.embedingView = view
        })
    }

    private func _checkIfCameraIsAvailable()
    {
        AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { (cameraAvailable) -> Void in
            if !cameraAvailable {
                self._show("Camera unavailable", message: "The app does not have access to camera")
            }
        })
    }
    
    private func _addVideoInput()
    {
        var error: NSError?
        
        var videoFrontDevice: AVCaptureDevice?
        var videoBackDevice: AVCaptureDevice?
        for device: AnyObject in AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) {
            if device.position == AVCaptureDevicePosition.Back {
                videoBackDevice = device as? AVCaptureDevice
            } else if device.position == AVCaptureDevicePosition.Front {
                videoFrontDevice = device as? AVCaptureDevice
            }
        }
        if let validVideoFrontDevice = videoFrontDevice? {
            self.frontCamera = AVCaptureDeviceInput.deviceInputWithDevice(validVideoFrontDevice, error: &error) as AVCaptureDeviceInput
        }
        if let validVideoBackDevice = videoBackDevice? {
            self.rearCamera = AVCaptureDeviceInput.deviceInputWithDevice(validVideoBackDevice, error: &error) as AVCaptureDeviceInput
            if !(error != nil) {
                if let validBackDevice = self.rearCamera? {
                    self.captureSession?.addInput(validBackDevice)
                }
            }
        }
    }
    
    private func _addStillImageOutput()
    {
        self.stillImageOutput = AVCaptureStillImageOutput()
        if let validStillImageOutput = self.stillImageOutput? {
            self.captureSession?.addOutput(self.stillImageOutput)
        }
    }

    private func _setupPreviewLayer()
    {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        self.previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
    }

    private func _show (title: String, message: String)
    {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.showErrorBlock(erTitle: title, erMessage: message)
        })
    }
}
