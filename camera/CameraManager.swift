//
//  CameraManager.swift
//  camera
//
//  Created by Natalia Terlecka on 10/10/14.
//  Copyright (c) 2014 imaginaryCloud. All rights reserved.
//

import UIKit
import AVFoundation
import AssetsLibrary

private let _singletonSharedInstance = CameraManager()

enum CameraDevice {
    case Front, Back
}

enum CameraFlashMode: Int {
    case Off, On, Auto
}

enum CameraOutputMode {
    case StillImage, VideoWithMic, VideoOnly
}

enum CameraOutputQuality {
    case Low, Medium, High
}

/// Class for handling iDevices custom camera usage
class CameraManager: NSObject, AVCaptureFileOutputRecordingDelegate {
   
    /// Capture sessioc to customize camera settings.
    var captureSession: AVCaptureSession?
    
    /// Property to determine if the manager should show the error for the user. If you want to show the errors yourself set this to false. If you want to add custom error UI set showErrorBlock property. Default value is true.
    var showErrorsToUsers = true
    
    /// A block creating UI to present error message to the user.
    var showErrorBlock:(erTitle: String, erMessage: String) -> Void = { (erTitle: String, erMessage: String) -> Void in
        UIAlertView(title: erTitle, message: erMessage, delegate: nil, cancelButtonTitle: "OK").show()
    }
    
    /// Property to determine if  manager should write the resources to the phone library. Default value is true.
    var writeFilesToPhoneLibrary = true

    /// The Bool property to determin if current device has front camera.
    var hasFrontCamera: Bool = {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for  device in devices  {
            let captureDevice = device as AVCaptureDevice
            if (captureDevice.position == AVCaptureDevicePosition.Front) {
                return true
            }
        }
        return false
    }()
    
    /// Property to change camera device between front and back.
    var cameraDevice: CameraDevice {
        get {
            return self.currentCameraDevice
        }
        set(newCameraDevice) {
            if let validCaptureSession = self.captureSession {
                validCaptureSession.beginConfiguration()
                let inputs = validCaptureSession.inputs as [AVCaptureInput]
                
                switch newCameraDevice {
                case .Front:
                    if self.hasFrontCamera {
                        if let validBackDevice = self.rearCamera? {
                            if contains(inputs, validBackDevice) {
                                validCaptureSession.removeInput(validBackDevice)
                            }
                        }
                        if let validFrontDevice = self.frontCamera? {
                            if !contains(inputs, validFrontDevice) {
                                validCaptureSession.addInput(validFrontDevice)
                            }
                        }
                    }
                case .Back:
                    if let validFrontDevice = self.frontCamera? {
                        if contains(inputs, validFrontDevice) {
                            validCaptureSession.removeInput(validFrontDevice)
                        }
                    }
                    if let validBackDevice = self.rearCamera? {
                        if !contains(inputs, validBackDevice) {
                            validCaptureSession.addInput(validBackDevice)
                        }
                    }
                }
                validCaptureSession.commitConfiguration()
            }
            self.currentCameraDevice = newCameraDevice
        }
    }
    
    /// Property to change camera flash mode.
    var flashMode: CameraFlashMode {
        get {
            return self.currentFlashMode
        }
        set(newflashMode) {
            if newflashMode != self.currentFlashMode {
                self.captureSession?.beginConfiguration()
                let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
                for  device in devices  {
                    let captureDevice = device as AVCaptureDevice
                    if (captureDevice.position == AVCaptureDevicePosition.Back) {
                        let avFlashMode = AVCaptureFlashMode.fromRaw(newflashMode.toRaw())
                        if (captureDevice.isFlashModeSupported(avFlashMode!)) {
                            captureDevice.lockForConfiguration(nil)
                            captureDevice.flashMode = avFlashMode!
                            captureDevice.unlockForConfiguration()
                        }
                    }
                }
                self.captureSession?.commitConfiguration()
                
                self.currentFlashMode = newflashMode
            }
        }
    }
    
    /// Property to change camera output quality.
    var cameraOutputQuality: CameraOutputQuality {
        get {
            return self.currentCameraOutputQuality
        }
        set(newCameraOutputQuality) {
            if newCameraOutputQuality != self.currentCameraOutputQuality {
                self.captureSession?.beginConfiguration()
                switch (newCameraOutputQuality) {
                case CameraOutputQuality.Low:
                    self.captureSession?.sessionPreset = AVCaptureSessionPresetLow
                case CameraOutputQuality.Medium:
                    self.captureSession?.sessionPreset = AVCaptureSessionPresetMedium
                case CameraOutputQuality.High:
                    self.captureSession?.sessionPreset = AVCaptureSessionPresetHigh
                }
                self.captureSession?.commitConfiguration()
                
                self.currentCameraOutputQuality = newCameraOutputQuality
            }
        }
    }
    
    /// Property to change camera output.
    var cameraOutputMode: CameraOutputMode {
        get {
            return self.currentCameraOutputMode
        }
        set(newCameraOutputMode) {
            if newCameraOutputMode != self.currentCameraOutputMode {
                self.captureSession?.beginConfiguration()

                // remove current setting
                switch self.currentCameraOutputMode {
                case .StillImage:
                    if let validStillImageOutput = self.stillImageOutput? {
                        self.captureSession?.removeOutput(validStillImageOutput)
                    }
                case .VideoOnly, .VideoWithMic:
                    if let validMovieOutput = self.movieOutput? {
                        self.captureSession?.removeOutput(validMovieOutput)
                    }
                    if self.currentCameraOutputMode == .VideoWithMic {
                        if let validMic = self.mic? {
                            self.captureSession?.removeInput(validMic)
                        }
                    }
                }
                // configure new devices
                switch newCameraOutputMode {
                case .StillImage:
                    if (self.stillImageOutput == nil) {
                        self._setupOutputs()
                    }
                    if let validStillImageOutput = self.stillImageOutput? {
                        self.captureSession?.addOutput(validStillImageOutput)
                    }
                case .VideoOnly, .VideoWithMic:
                    if (self.movieOutput == nil) {
                        self._setupOutputs()
                    }
                    if let validMovieOutput = self.movieOutput? {
                        self.captureSession?.addOutput(validMovieOutput)
                    }
                    if self.currentCameraOutputMode == .VideoWithMic {
                        if (self.mic == nil) {
                            self._setupMic()
                        }
                        if let validMic = self.mic? {
                            self.captureSession?.addInput(validMic)
                        }
                    }
                }
                self.captureSession?.commitConfiguration()
                
                self.currentCameraOutputMode = newCameraOutputMode
            }
        }
    }
    
    private weak var embedingView: UIView?
    private var videoCompletition: ((videoURL: NSURL) -> Void)?
    
    private var sessionQueue: dispatch_queue_t = dispatch_queue_create("CameraSessionQueue", DISPATCH_QUEUE_SERIAL)

    private var frontCamera: AVCaptureInput?
    private var rearCamera: AVCaptureInput?
    private var mic: AVCaptureDeviceInput?
    private var stillImageOutput: AVCaptureStillImageOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var library: ALAssetsLibrary?
    
    private var cameraIsSetup = false
    
    private var currentCameraDevice = CameraDevice.Back
    private var currentFlashMode = CameraFlashMode.Off
    private var currentCameraOutputMode = CameraOutputMode.StillImage
    private var currentCameraOutputQuality = CameraOutputQuality.High
    
    private var tempFilePath: NSURL = {
        let tempPath = NSTemporaryDirectory().stringByAppendingPathComponent("tempMovie").stringByAppendingPathExtension("mp4")
        if NSFileManager.defaultManager().fileExistsAtPath(tempPath!) {
            NSFileManager.defaultManager().removeItemAtPath(tempPath!, error: nil)
        }
        return NSURL(fileURLWithPath: tempPath!)
        }()
    
    /// CameraManager singleton instance to use the camera.
    class var sharedInstance: CameraManager {
        return _singletonSharedInstance
    }
    
    deinit {
        self.stopAndRemoveCaptureSession()
        self._stopFollowingDeviceOrientation()
    }
    
    /**
    Inits a capture session and adds a preview layer to the given view. Preview layer bounds will automaticaly be set to match given view.
    
    :param: view The view you want to add the preview layer to
    :param: cameraOutputMode The mode you want capturesession to run image / video / video and microphone
    */
    func addPreviewLayerToView(view: UIView)
    {
        self.addPreviewLayerToView(view, newCameraOutputMode: self.currentCameraOutputMode)
    }
    func addPreviewLayerToView(view: UIView, newCameraOutputMode: CameraOutputMode)
    {
        if let validEmbedingView = self.embedingView? {
            if let validPreviewLayer = self.previewLayer? {
                validPreviewLayer.removeFromSuperlayer()
            }
        }
        if self.cameraIsSetup {
            self._addPreeviewLayerToView(view)
            self.cameraOutputMode = newCameraOutputMode
        } else {
            self._setupCamera({ Void -> Void in
                self._addPreeviewLayerToView(view)
                self.cameraOutputMode = newCameraOutputMode
            })
        }
    }
    
    /**
    Stops running capture session but all setup devices, inputs and outputs stay for further reuse.
    */
    func stopCaptureSession()
    {
        self.captureSession?.stopRunning()
    }
    
    /**
    Stops running capture session and removes all setup devices, inputs and outputs.
    */
    func stopAndRemoveCaptureSession()
    {
        self.stopCaptureSession()
        self.cameraDevice = .Back
        self.cameraIsSetup = false
        self.previewLayer = nil
        self.captureSession = nil
        self.frontCamera = nil
        self.rearCamera = nil
        self.mic = nil
        self.stillImageOutput = nil
        self.movieOutput = nil
    }
    
    /**
    Captures still image from currently running capture session.
    
    :param: imageCompletition Completition block containing the captured UIImage
    */
    func capturePictureWithCompletition(imageCompletition: UIImage -> Void)
    {
        if self.cameraIsSetup {
            if self.cameraOutputMode == .StillImage {
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
                                if let weakSelf = self {
                                    if weakSelf.writeFilesToPhoneLibrary {
                                        if let validLibrary = weakSelf.library? {
                                            validLibrary.writeImageDataToSavedPhotosAlbum(imageData, metadata:nil, completionBlock: {
                                                (picUrl, error) -> Void in
                                                if (error? != nil) {
                                                    dispatch_async(dispatch_get_main_queue(), {
                                                        weakSelf._show("error", message: error.localizedDescription)
                                                    })
                                                }
                                            })
                                        }
                                    }
                                }
                                imageCompletition(UIImage(data: imageData))
                            }
                        })
                    }
                })
            } else {
                self._show("Capture session output mode video", message: "I can't take any picture")
            }
        } else {
            self._show("No capture session setup", message: "I can't take any picture")
        }
    }
    
    /**
    Starts recording a video with or without voice as in the session preset.
    */
    func startRecordingVideo()
    {
        if self.cameraOutputMode != .StillImage {
            self.movieOutput?.startRecordingToOutputFileURL(self.tempFilePath, recordingDelegate: self)
        } else {
            self._show("Capture session output still image", message: "I can only take pictures")
        }
    }
    
    /**
    Stop recording a video. Save it to the cameraRoll and give back the url.
    */
    func stopRecordingVideo(completition:(videoURL: NSURL) -> Void)
    {
        if let runningMovieOutput = self.movieOutput {
            if runningMovieOutput.recording {
                self.videoCompletition = completition
                runningMovieOutput.stopRecording()
            }
        }
    }
    
    
    // PRAGMA MARK - AVCaptureFileOutputRecordingDelegate
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!)
    {
        
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!)
    {
        if (error != nil) {
            self._show("Unable to save video to the iPhone", message: error.localizedDescription)
        } else {
            if let validLibrary = self.library? {
                if self.writeFilesToPhoneLibrary {
                    validLibrary.writeVideoAtPathToSavedPhotosAlbum(outputFileURL, completionBlock: { (assetURL: NSURL?, error: NSError?) -> Void in
                        if (error != nil) {
                            self._show("Unable to save video to the iPhone.", message: error!.localizedDescription)
                        } else {
                            if let validAssetURL = assetURL {
                                self._executeVideoCompletitionWithURL(validAssetURL)
                            }
                        }
                    })
                } else {
                    self._executeVideoCompletitionWithURL(outputFileURL)
                }
            }
        }
    }
    
    // PRAGMA MARK - CameraManager()

    private func _executeVideoCompletitionWithURL(url: NSURL)
    {
        if let validCompletition = self.videoCompletition {
            validCompletition(videoURL: url)
            self.videoCompletition = nil
        }
    }
    
    @objc private func _orientationChanged()
    {
        if let validPreviewLayer = self.previewLayer? {
            if let validPreviewLayerConnection = validPreviewLayer.connection? {
                switch UIDevice.currentDevice().orientation {
                case .LandscapeLeft:
                    validPreviewLayerConnection.videoOrientation = .LandscapeRight
                case .LandscapeRight:
                    validPreviewLayerConnection.videoOrientation = .LandscapeLeft
                default:
                    validPreviewLayerConnection.videoOrientation = .Portrait
                }
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    if let validEmbedingView = self.embedingView? {
                        validPreviewLayer.frame = validEmbedingView.bounds
                    }
                })
            }
        }
    }
    
    private func _setupCamera(completition: Void -> Void)
    {
        if self._checkIfCameraIsAvailable() {
            self.captureSession = AVCaptureSession()
            self.captureSession?.sessionPreset = AVCaptureSessionPresetPhoto
            
            dispatch_async(sessionQueue, {
                if let validCaptureSession = self.captureSession? {
                    validCaptureSession.beginConfiguration()
                    validCaptureSession.sessionPreset = AVCaptureSessionPresetHigh
                    self._addVideoInput()
                    self._setupOutputs()
                    self.cameraOutputMode = self.currentCameraOutputMode
                    self._setupPreviewLayer()
                    validCaptureSession.commitConfiguration()
                    validCaptureSession.startRunning()
                    self._startFollowingDeviceOrientation()
                    completition()
                    self.cameraIsSetup = true
                }
            })
        } else {
           self._show("Camera unavailable", message: "The device does not have a camera")
        }
    }
    
    private func _startFollowingDeviceOrientation()
    {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "_orientationChanged", name: UIDeviceOrientationDidChangeNotification, object: nil)
    }
    
    private func _stopFollowingDeviceOrientation()
    {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
    }

    private func _addPreeviewLayerToView(view: UIView)
    {
        self.embedingView = view
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.previewLayer?.frame = view.layer.bounds
            view.clipsToBounds = true
            view.layer.addSublayer(self.previewLayer)
        })
    }

    private func _checkIfCameraIsAvailable() -> Bool
    {
        let deviceHasCamera = UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Rear) || UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Front)
        return deviceHasCamera
    }
    
    private func _addVideoInput()
    {
        var error: NSError?
        
        if (self.frontCamera? == nil) || (self.rearCamera? == nil) {
            var videoFrontDevice: AVCaptureDevice?
            var videoBackDevice: AVCaptureDevice?
            for device: AnyObject in AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) {
                if device.position == AVCaptureDevicePosition.Back {
                    videoBackDevice = device as? AVCaptureDevice
                } else if device.position == AVCaptureDevicePosition.Front {
                    videoFrontDevice = device as? AVCaptureDevice
                }
            }
            if (self.frontCamera? == nil) {
                if let validVideoFrontDevice = videoFrontDevice? {
                    self.frontCamera = AVCaptureDeviceInput.deviceInputWithDevice(validVideoFrontDevice, error: &error) as AVCaptureDeviceInput
                }
            }
            if (self.rearCamera? == nil) {
                if let validVideoBackDevice = videoBackDevice? {
                    self.rearCamera = AVCaptureDeviceInput.deviceInputWithDevice(validVideoBackDevice, error: &error) as AVCaptureDeviceInput
                }
            }
            if let validError = error? {
                self._show("Device setup error occured", message: validError.localizedDescription)
            }
        }
        self.cameraDevice = self.currentCameraDevice
    }
    
    private func _setupMic()
    {
        if (self.mic == nil) {
            var error: NSError?
            let micDevice:AVCaptureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio);
            self.mic = AVCaptureDeviceInput.deviceInputWithDevice(micDevice, error: &error) as? AVCaptureDeviceInput;
            if let errorHappened = error? {
                self.mic = nil
                self._show("Mic error", message: errorHappened.description)
            }
        }
    }
    
    private func _setupOutputs()
    {
        if (self.stillImageOutput == nil) {
            self.stillImageOutput = AVCaptureStillImageOutput()
        }
        if (self.movieOutput == nil) {
            self.movieOutput = AVCaptureMovieFileOutput()
        }
        if self.library == nil {
            self.library = ALAssetsLibrary()
        }
    }
    
    private func _setupPreviewLayer()
    {
        if let validCaptureSession = self.captureSession? {
            self.previewLayer = AVCaptureVideoPreviewLayer(session: validCaptureSession)
            self.previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        }
    }

    private func _show (title: String, message: String)
    {
        if self.showErrorsToUsers {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.showErrorBlock(erTitle: title, erMessage: message)
            })
        }
    }
}
