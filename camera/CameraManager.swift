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

/// Class for handling iDevices custom camera usage
class CameraManager: NSObject, AVCaptureFileOutputRecordingDelegate {
   
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
    
    /// A block creating UI to present error message to the user.
    var showErrorBlock:(erTitle: String, erMessage: String) -> Void = { (erTitle: String, erMessage: String) -> Void in
        UIAlertView(title: erTitle, message: erMessage, delegate: nil, cancelButtonTitle: "OK").show()
    }
    
    /// Property to change camera device between front and back.
    var cameraDevice: CameraDevice {
        get {
            return self.currentCameraDevice
        }
        set(newCameraDevice) {
            if newCameraDevice != self.currentCameraDevice {
                self.captureSession?.beginConfiguration()
                
                switch newCameraDevice {
                case .Front:
                    if self.hasFrontCamera {
                        if let validBackDevice = self.rearCamera? {
                            self.captureSession?.removeInput(validBackDevice)
                        }
                        if let validFrontDevice = self.frontCamera? {
                            self.captureSession?.addInput(validFrontDevice)
                        }
                    }
                case .Back:
                    if let validFrontDevice = self.frontCamera? {
                        self.captureSession?.removeInput(validFrontDevice)
                    }
                    if let validBackDevice = self.rearCamera? {
                        self.captureSession?.addInput(validBackDevice)
                    }
                }
                self.captureSession?.commitConfiguration()
                
                self.currentCameraDevice = newCameraDevice
            }
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
                        self._setupStillImageOutput()
                    }
                    if let validStillImageOutput = self.stillImageOutput? {
                        self.captureSession?.addOutput(validStillImageOutput)
                    }
                    self.captureSession?.sessionPreset = AVCaptureSessionPresetPhoto

                case .VideoOnly, .VideoWithMic:
                    if (self.movieOutput == nil) {
                        self._setupMovieOutput()
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
                    self.captureSession?.sessionPreset = AVCaptureSessionPresetMedium

                }
                self.captureSession?.commitConfiguration()
                
                self.currentCameraOutputMode = newCameraOutputMode
            }
        }
    }
    
    /// Capture sessioc to customize camera settings.
    var captureSession: AVCaptureSession?

    private weak var embedingView: UIView?
    private var videoCompletition: ((videoURL: NSURL) -> Void)?
    
    private var sessionQueue: dispatch_queue_t = dispatch_queue_create("CameraSessionQueue", DISPATCH_QUEUE_SERIAL)

    private var frontCamera: AVCaptureInput?
    private var rearCamera: AVCaptureInput?
    private var mic: AVCaptureDeviceInput?
    private var stillImageOutput: AVCaptureStillImageOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var cameraIsSetup = false
    
    private var currentCameraDevice = CameraDevice.Back
    private var currentFlashMode = CameraFlashMode.Off
    private var currentCameraOutputMode = CameraOutputMode.StillImage
    
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
    func addPreeviewLayerToView(view: UIView, cameraOutputMode: CameraOutputMode)
    {
        if let validEmbedingView = self.embedingView? {
            if let validPreviewLayer = self.previewLayer? {
                validPreviewLayer.removeFromSuperlayer()
            }
        }
        if self.cameraIsSetup {
            self._addPreeviewLayerToView(view)
            self.cameraOutputMode = cameraOutputMode
        } else {
            self._setupCamera({ Void -> Void in
                self._addPreeviewLayerToView(view)
                self.cameraOutputMode = cameraOutputMode
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
    Stop recording a video.
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
            let library = ALAssetsLibrary()
            library.writeVideoAtPathToSavedPhotosAlbum(outputFileURL, completionBlock: { (assetURL: NSURL?, error: NSError?) -> Void in
                if (error != nil) {
                    self._show("Unable to save video to the iPhone.", message: error!.localizedDescription)
                } else {
                    if let validCompletition = self.videoCompletition {
                        if let validAssetURL = assetURL {
                            validCompletition(videoURL: validAssetURL)
                            self.videoCompletition = nil
                        }
                    }
                }
            })
        }
    }

    
    // PRAGMA MARK - CameraManager()

    @objc private func _orientationChanged()
    {
        if let validPreviewLayer = self.previewLayer {
            switch UIDevice.currentDevice().orientation {
            case .LandscapeLeft:
                validPreviewLayer.connection.videoOrientation = .LandscapeRight
            case .LandscapeRight:
                validPreviewLayer.connection.videoOrientation = .LandscapeLeft
            default:
                validPreviewLayer.connection.videoOrientation = .Portrait
            }
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                if let validEmbedingView = self.embedingView? {
                    validPreviewLayer.frame = validEmbedingView.bounds
                }
            })
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
                    self._addVideoInput()
                    self._setupStillImageOutput()
                    if let validStillImageOutput = self.stillImageOutput? {
                        self.captureSession?.addOutput(self.stillImageOutput)
                    }
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
            self.hasFrontCamera = true
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
    
    private func _setupMic()
    {
        if (self.mic == nil) {
            var error: NSError?
            let micDevice:AVCaptureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio);
            self.mic = AVCaptureDeviceInput.deviceInputWithDevice(micDevice, error: &error) as? AVCaptureDeviceInput;
            if let errorHappened = error {
                self.mic = nil
                self._show("Mic error", message: errorHappened.description)
            }
        }
    }
    
    private func _setupStillImageOutput()
    {
        if (self.stillImageOutput == nil) {
            self.stillImageOutput = AVCaptureStillImageOutput()
        }
    }
    
    private func _setupMovieOutput()
    {
        if (self.movieOutput == nil) {
            self.movieOutput = AVCaptureMovieFileOutput()
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
