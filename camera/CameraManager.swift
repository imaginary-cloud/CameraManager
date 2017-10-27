//
//  CameraManager.swift
//  camera
//
//  Created by Natalia Terlecka on 10/10/14.
//  Copyright (c) 2014 imaginaryCloud. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import ImageIO
import MobileCoreServices
import Photos
import CoreLocation

public enum CameraState {
    case ready, accessDenied, noDeviceFound, notDetermined
}

public enum CameraDevice {
    case front, back
}

public enum CameraFlashMode: Int {
    case off, on, auto
}

public enum CameraOutputMode {
    case stillImage, videoWithMic, videoOnly
}

public enum CameraOutputQuality: Int {
    case low, medium, high
}

/// Class for handling iDevices custom camera usage
open class CameraManager: NSObject, AVCaptureFileOutputRecordingDelegate, UIGestureRecognizerDelegate {
    
    // MARK: - Public properties
    
    /// Capture session to customize camera settings.
    open var captureSession: AVCaptureSession?
    
    /// Property to determine if the manager should show the error for the user. If you want to show the errors yourself set this to false. If you want to add custom error UI set showErrorBlock property. Default value is false.
    open var showErrorsToUsers = false
    
    /// Property to determine if the manager should show the camera permission popup immediatly when it's needed or you want to show it manually. Default value is true. Be carful cause using the camera requires permission, if you set this value to false and don't ask manually you won't be able to use the camera.
    open var showAccessPermissionPopupAutomatically = true
    
    /// A block creating UI to present error message to the user. This can be customised to be presented on the Window root view controller, or to pass in the viewController which will present the UIAlertController, for example.
    open var showErrorBlock:(_ erTitle: String, _ erMessage: String) -> Void = { (erTitle: String, erMessage: String) -> Void in
        
        //        var alertController = UIAlertController(title: erTitle, message: erMessage, preferredStyle: .Alert)
        //        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (alertAction) -> Void in  }))
        //
        //        if let topController = UIApplication.sharedApplication().keyWindow?.rootViewController {
        //            topController.presentViewController(alertController, animated: true, completion:nil)
        //        }
    }
    
    /// Property to determine if manager should write the resources to the phone library. Default value is true.
    open var writeFilesToPhoneLibrary = true

    // Allow to save location on images when saving to library. Default value is true.
    open var saveLocationOnImages = true
    
    /// Property to determine if manager should follow device orientation. Default value is true.
    open var shouldRespondToOrientationChanges = true {
        didSet {
            if shouldRespondToOrientationChanges {
                _startFollowingDeviceOrientation()
            } else {
                _stopFollowingDeviceOrientation()
            }
        }
    }
    
    /// Property to determine if manager should horizontally flip image took by front camera. Default value is false.
    open var shouldFlipFrontCameraImage = false
    
    open var shouldKeepViewAtOrientationChanges = false
    
    /// Property to determine if manager should enable tap to focus on camera preview. Default value is true.
    open var shouldEnableTapToFocus = true {
        didSet {
            focusGesture.isEnabled = shouldEnableTapToFocus
        }
    }
    
    /// Property to determine if manager should enable pinch to zoom on camera preview. Default value is true.
    open var shouldEnablePinchToZoom = true {
        didSet {
            zoomGesture.isEnabled = shouldEnablePinchToZoom
        }
    }
    
    /// The Bool property to determine if the camera is ready to use.
    open var cameraIsReady: Bool {
        get {
            return cameraIsSetup
        }
    }
    
    /// The Bool property to determine if current device has front camera.
    open var hasFrontCamera: Bool = {
        let frontDevices = AVCaptureDevice.videoDevices.filter { $0.position == .front }
        return !frontDevices.isEmpty
    }()
    
    /// The Bool property to determine if current device has flash.
    open var hasFlash: Bool = {
        let hasFlashDevices = AVCaptureDevice.videoDevices.filter { $0.hasFlash }
        return !hasFlashDevices.isEmpty
    }()
    
    /// Property to enable or disable flip animation when switch between back and front camera. Default value is true.
    open var animateCameraDeviceChange: Bool = true
    
    /// Property to enable or disable shutter animation when taking a picture. Default value is true.
    open var animateShutter: Bool = true
    
    /// Property to enable or disable location services. Location services in camera is used for EXIF data. Default is false
    open var shouldUseLocationServices: Bool = false {
        didSet {
            if shouldUseLocationServices == true {
                self.locationManager = CameraLocationManager()
            }
        }
    }
    
    /// Property to change camera device between front and back.
    open var cameraDevice = CameraDevice.back {
        didSet {
            if cameraIsSetup {
                if cameraDevice != oldValue {
                    if animateCameraDeviceChange {
                        _doFlipAnimation()
                    }
                    _updateCameraDevice(cameraDevice)
                    _updateFlashMode(flashMode)
                    _setupMaxZoomScale()
                    _zoom(0)
                }
            }
        }
    }
    
    /// Property to change camera flash mode.
    open var flashMode = CameraFlashMode.off {
        didSet {
            if cameraIsSetup {
                if flashMode != oldValue {
                    _updateFlashMode(flashMode)
                    print("Flash Mode: \(flashMode.rawValue)")
                }
            }
        }
    }
    
    /// Property to change camera output quality.
    open var cameraOutputQuality = CameraOutputQuality.high {
        didSet {
            if cameraIsSetup {
                if cameraOutputQuality != oldValue {
                    _updateCameraQualityMode(cameraOutputQuality)
                }
            }
        }
    }
    
    /// Property to change camera output.
    open var cameraOutputMode = CameraOutputMode.stillImage {
        didSet {
            if cameraIsSetup {
                if cameraOutputMode != oldValue {
                    _setupOutputMode(cameraOutputMode, oldCameraOutputMode: oldValue)
                }
                _setupMaxZoomScale()
                _zoom(0)
            }
        }
    }
    
    /// Property to check video recording duration when in progress
    open var recordedDuration : CMTime { return movieOutput?.recordedDuration ?? kCMTimeZero }
    
    /// Property to check video recording file size when in progress
    open var recordedFileSize : Int64 { return movieOutput?.recordedFileSize ?? 0 }
    
    //Properties to set focus and capture mode when tap to focus is used (_focusStart)
    open var focusMode : AVCaptureDevice.FocusMode = .continuousAutoFocus
    open var exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure
    
    
    // MARK: - Private properties
    
    fileprivate var locationManager: CameraLocationManager?

    fileprivate weak var embeddingView: UIView?
    fileprivate var videoCompletion: ((_ videoURL: URL?, _ error: NSError?) -> Void)?
    
    fileprivate var sessionQueue: DispatchQueue = DispatchQueue(label: "CameraSessionQueue", attributes: [])
    
    fileprivate lazy var frontCameraDevice: AVCaptureDevice? = {
        return AVCaptureDevice.videoDevices.filter { $0.position == .front }.first
    }()
    
    fileprivate lazy var backCameraDevice: AVCaptureDevice? = {
        return AVCaptureDevice.videoDevices.filter { $0.position == .back }.first
    }()
    
    fileprivate lazy var mic: AVCaptureDevice? = {
        return AVCaptureDevice.default(for: AVMediaType.audio)
    }()
    
    fileprivate var stillImageOutput: AVCaptureStillImageOutput?
    fileprivate var movieOutput: AVCaptureMovieFileOutput?
    fileprivate var previewLayer: AVCaptureVideoPreviewLayer?
    fileprivate var library: PHPhotoLibrary?
    
    fileprivate var cameraIsSetup = false
    fileprivate var cameraIsObservingDeviceOrientation = false
    
    fileprivate var zoomScale       = CGFloat(1.0)
    fileprivate var beginZoomScale  = CGFloat(1.0)
    fileprivate var maxZoomScale    = CGFloat(1.0)
    
    fileprivate func _tempFilePath() -> URL {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempMovie\(Date().timeIntervalSince1970)").appendingPathExtension("mp4")
        return tempURL
    }
    
    
    // MARK: - CameraManager
    
    /**
     Inits a capture session and adds a preview layer to the given view. Preview layer bounds will automaticaly be set to match given view. Default session is initialized with still image output.
     
     :param: view The view you want to add the preview layer to
     :param: cameraOutputMode The mode you want capturesession to run image / video / video and microphone
     :param: completion Optional completion block
     
     :returns: Current state of the camera: Ready / AccessDenied / NoDeviceFound / NotDetermined.
     */
    open func addPreviewLayerToView(_ view: UIView) -> CameraState {
        return addPreviewLayerToView(view, newCameraOutputMode: cameraOutputMode)
    }
    open func addPreviewLayerToView(_ view: UIView, newCameraOutputMode: CameraOutputMode) -> CameraState {
        return addLayerPreviewToView(view, newCameraOutputMode: newCameraOutputMode, completion: nil)
    }
    
    open func addLayerPreviewToView(_ view: UIView, newCameraOutputMode: CameraOutputMode, completion: (() -> Void)?) -> CameraState {
        if _canLoadCamera() {
            if let _ = embeddingView {
                if let validPreviewLayer = previewLayer {
                    validPreviewLayer.removeFromSuperlayer()
                }
            }
            if cameraIsSetup {
                _addPreviewLayerToView(view)
                cameraOutputMode = newCameraOutputMode
                if let validCompletion = completion {
                    validCompletion()
                }
            } else {
                _setupCamera {
                    self._addPreviewLayerToView(view)
                    self.cameraOutputMode = newCameraOutputMode
                    if let validCompletion = completion {
                        validCompletion()
                    }
                }
            }
        }
        return _checkIfCameraIsAvailable()
    }
    
    /**
     Asks the user for camera permissions. Only works if the permissions are not yet determined. Note that it'll also automaticaly ask about the microphone permissions if you selected VideoWithMic output.
     
     :param: completion Completion block with the result of permission request
     */
    open func askUserForCameraPermission(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (allowedAccess) -> Void in
            if self.cameraOutputMode == .videoWithMic {
                AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: { (allowedAccess) -> Void in
                    DispatchQueue.main.async(execute: { () -> Void in
                        completion(allowedAccess)
                    })
                })
            } else {
                DispatchQueue.main.async(execute: { () -> Void in
                    completion(allowedAccess)
                })
                
            }
        })
    }
    
    /**
     Stops running capture session but all setup devices, inputs and outputs stay for further reuse.
     */
    open func stopCaptureSession() {
        captureSession?.stopRunning()
        _stopFollowingDeviceOrientation()
    }
    
    /**
     Resumes capture session.
     */
    open func resumeCaptureSession() {
        if let validCaptureSession = captureSession {
            if !validCaptureSession.isRunning && cameraIsSetup {
                validCaptureSession.startRunning()
                _startFollowingDeviceOrientation()
            }
        } else {
            if _canLoadCamera() {
                if cameraIsSetup {
                    stopAndRemoveCaptureSession()
                }
                _setupCamera {
                    if let validEmbeddingView = self.embeddingView {
                        self._addPreviewLayerToView(validEmbeddingView)
                    }
                    self._startFollowingDeviceOrientation()
                }
            }
        }
    }
    
    /**
     Stops running capture session and removes all setup devices, inputs and outputs.
     */
    open func stopAndRemoveCaptureSession() {
        stopCaptureSession()
        let oldAnimationValue = animateCameraDeviceChange
        animateCameraDeviceChange = false
        cameraDevice = .back
        cameraIsSetup = false
        previewLayer = nil
        captureSession = nil
        frontCameraDevice = nil
        backCameraDevice = nil
        mic = nil
        stillImageOutput = nil
        movieOutput = nil
        animateCameraDeviceChange = oldAnimationValue
    }
    
    /**
     Captures still image from currently running capture session.
     
     :param: imageCompletion Completion block containing the captured UIImage
     */
    open func capturePictureWithCompletion(_ imageCompletion: @escaping (UIImage?, NSError?) -> Void) {
        
        if writeFilesToPhoneLibrary && saveLocationOnImages && locationManager == nil {
            locationManager = CameraLocationManager()
        }
        
        self.capturePictureDataWithCompletion { data, error in
            
            guard error == nil, let imageData = data else {
                imageCompletion(nil, error)
                return
            }
            
            if self.animateShutter {
                self._performShutterAnimation() {
                    self._capturePicture(imageData, imageCompletion)
                }
            } else {
                self._capturePicture(imageData, imageCompletion)
            }
        }
    }
    
    fileprivate func _capturePicture(_ imageData: Data, _ imageCompletion: (UIImage?, NSError?) -> Void) {
        guard let tempImage = UIImage(data: imageData) else {
            imageCompletion(nil, NSError())
            return
        }
        
        let image: UIImage
        if self.shouldFlipFrontCameraImage == true, self.cameraDevice == .front {
            guard let cgImage = tempImage.cgImage else {
                imageCompletion(nil, NSError())
                return
            }
            let flippedImage = UIImage(cgImage: cgImage, scale: tempImage.scale, orientation: .leftMirrored)
            image = flippedImage
        } else {
            image = tempImage
        }
        
        if self.writeFilesToPhoneLibrary == true, let library = self.library  {
            library.performChanges({
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                request.creationDate = Date()
                
                if let location = self.locationManager?.latestLocation {
                    request.location = location
                }
            }, completionHandler: { success, error in
                if let error = error {
                    DispatchQueue.main.async(execute: {
                        self._show(NSLocalizedString("Error", comment:""), message: error.localizedDescription)
                    })
                }
            })
        }
        
        imageCompletion(image, nil)
    }
    
    /**
     Captures still image from currently running capture session.
     
     :param: imageCompletion Completion block containing the captured imageData
     */
    open func capturePictureDataWithCompletion(_ imageCompletion: @escaping (Data?, NSError?) -> Void) {
        
        guard cameraIsSetup else {
            _show(NSLocalizedString("No capture session setup", comment:""), message: NSLocalizedString("I can't take any picture", comment:""))
            return
        }
        
        guard cameraOutputMode == .stillImage else {
            _show(NSLocalizedString("Capture session output mode video", comment:""), message: NSLocalizedString("I can't take any picture", comment:""))
            return
        }
        
        sessionQueue.async(execute: {
            let stillImageOutput = self._getStillImageOutput()
            stillImageOutput.captureStillImageAsynchronously(from: stillImageOutput.connection(with: AVMediaType.video)!, completionHandler: { [weak self] sample, error in
                
                if let error = error {
                    DispatchQueue.main.async(execute: {
                        self?._show(NSLocalizedString("Error", comment:""), message: error.localizedDescription)
                    })
                    imageCompletion(nil, error as NSError?)
                    return
                }
                
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sample!)
                imageCompletion(imageData, nil)
                
            })
        })
        
    }
    
    /**
     Starts recording a video with or without voice as in the session preset.
     */
    open func startRecordingVideo() {
        if cameraOutputMode != .stillImage {
            _getMovieOutput().startRecording(to: _tempFilePath(), recordingDelegate: self)
        } else {
            _show(NSLocalizedString("Capture session output still image", comment:""), message: NSLocalizedString("I can only take pictures", comment:""))
        }
    }
    
    /**
     Stop recording a video. Save it to the cameraRoll and give back the url.
     */
    open func stopVideoRecording(_ completion:((_ videoURL: URL?, _ error: NSError?) -> Void)?) {
        if let runningMovieOutput = movieOutput {
            if runningMovieOutput.isRecording {
                videoCompletion = completion
                runningMovieOutput.stopRecording()
            }
        }
    }
    
    /**
     Current camera status.
     
     :returns: Current state of the camera: Ready / AccessDenied / NoDeviceFound / NotDetermined
     */
    open func currentCameraStatus() -> CameraState {
        return _checkIfCameraIsAvailable()
    }
    
    /**
     Change current flash mode to next value from available ones.
     
     :returns: Current flash mode: Off / On / Auto
     */
    open func changeFlashMode() -> CameraFlashMode {
        guard let newFlashMode = CameraFlashMode(rawValue: (flashMode.rawValue+1)%3) else { return flashMode }
        flashMode = newFlashMode
        return flashMode
    }
    
    /**
     Change current output quality mode to next value from available ones.
     
     :returns: Current quality mode: Low / Medium / High
     */
    open func changeQualityMode() -> CameraOutputQuality {
        guard let newQuality = CameraOutputQuality(rawValue: (cameraOutputQuality.rawValue+1)%3) else { return cameraOutputQuality }
        cameraOutputQuality = newQuality
        return cameraOutputQuality
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate
    public func fileOutput(captureOutput: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        captureSession?.beginConfiguration()
        if flashMode != .off {
            _updateFlashMode(flashMode)
        }
        captureSession?.commitConfiguration()
    }
    
    open func fileOutput(_ captureOutput: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        _updateFlashMode(.off)
        if let error = error {
            _show(NSLocalizedString("Unable to save video to the iPhone", comment:""), message: error.localizedDescription)
        }
        else {
            if writeFilesToPhoneLibrary {
                if PHPhotoLibrary.authorizationStatus() == .authorized {
                    saveVideoToLibrary(outputFileURL)
                }
                else {
                    PHPhotoLibrary.requestAuthorization({ (autorizationStatus) in
                        if autorizationStatus == .authorized {
                            self.saveVideoToLibrary(outputFileURL)
                        }
                    })
                }
                
            } else {
                _executeVideoCompletionWithURL(outputFileURL, error: error as NSError?)
            }
        }
    }
    
    fileprivate func saveVideoToLibrary(_ fileURL: URL) {
        if let validLibrary = library {
            validLibrary.performChanges({
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
                request?.creationDate = Date()
                
                if let location = self.locationManager?.latestLocation {
                    request?.location = location
                }
            }, completionHandler: { success, error in
                if let error = error {
                    self._show(NSLocalizedString("Unable to save video to the iPhone.", comment:""), message: error.localizedDescription)
                    self._executeVideoCompletionWithURL(nil, error: error as NSError?)
                } else {
                    self._executeVideoCompletionWithURL(fileURL, error: error as NSError?)
                }
            })
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    fileprivate lazy var zoomGesture = UIPinchGestureRecognizer()
    
    fileprivate func attachZoom(_ view: UIView) {
        DispatchQueue.main.async {
            self.zoomGesture.addTarget(self, action: #selector(CameraManager._zoomStart(_:)))
            view.addGestureRecognizer(self.zoomGesture)
            self.zoomGesture.delegate = self
        }
    }
    
    open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if gestureRecognizer.isKind(of: UIPinchGestureRecognizer.self) {
            beginZoomScale = zoomScale;
        }
        
        return true
    }
    
    @objc
    fileprivate func _zoomStart(_ recognizer: UIPinchGestureRecognizer) {
        guard let view = embeddingView,
            let previewLayer = previewLayer
            else { return }
        
        var allTouchesOnPreviewLayer = true
        let numTouch = recognizer.numberOfTouches
        
        for i in 0 ..< numTouch {
            let location = recognizer.location(ofTouch: i, in: view)
            let convertedTouch = previewLayer.convert(location, from: previewLayer.superlayer)
            if !previewLayer.contains(convertedTouch) {
                allTouchesOnPreviewLayer = false
                break
            }
        }
        if allTouchesOnPreviewLayer {
            _zoom(recognizer.scale)
        }
    }
    
    fileprivate func _zoom(_ scale: CGFloat) {
        let device: AVCaptureDevice?
        
        switch cameraDevice {
        case .back:
            device = backCameraDevice
        case .front:
            device = frontCameraDevice
        }
        
        do {
            let captureDevice = device
            try captureDevice?.lockForConfiguration()
            
            zoomScale = max(1.0, min(beginZoomScale * scale, maxZoomScale))
            
            captureDevice?.videoZoomFactor = zoomScale
            
            captureDevice?.unlockForConfiguration()

        } catch {
            print("Error locking configuration")
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    fileprivate lazy var focusGesture = UITapGestureRecognizer()
    
    fileprivate func attachFocus(_ view: UIView) {
        DispatchQueue.main.async {
            self.zoomGesture.addTarget(self, action: #selector(CameraManager._zoomStart(_:)))
            view.addGestureRecognizer(self.focusGesture)
            self.zoomGesture.delegate = self
        }
    }
    
    @objc fileprivate func _focusStart(_ recognizer: UITapGestureRecognizer) {
        
        let device: AVCaptureDevice?
        
        switch cameraDevice {
        case .back:
            device = backCameraDevice
        case .front:
            device = frontCameraDevice
        }
        
        if let validDevice = device {
            
            if let validPreviewLayer = previewLayer,
                let view = recognizer.view
            {
                let pointInPreviewLayer = view.layer.convert(recognizer.location(in: view), to: validPreviewLayer)
                let pointOfInterest = validPreviewLayer.captureDevicePointConverted(fromLayerPoint: pointInPreviewLayer)
                
                do {
                    try validDevice.lockForConfiguration()
                    
                    _showFocusRectangleAtPoint(pointInPreviewLayer, inLayer: validPreviewLayer)
                    
                    if validDevice.isFocusPointOfInterestSupported {
                        validDevice.focusPointOfInterest = pointOfInterest;
                    }
                    
                    if  validDevice.isExposurePointOfInterestSupported {
                        validDevice.exposurePointOfInterest = pointOfInterest;
                    }
                    
                    if validDevice.isFocusModeSupported(focusMode) {
                        validDevice.focusMode = focusMode
                    }
                    
                    if validDevice.isExposureModeSupported(exposureMode) {
                        validDevice.exposureMode = exposureMode
                    }
                    
                    validDevice.unlockForConfiguration()
                }
                catch let error {
                    print(error)
                }
            }
        }
    }
    
    fileprivate var lastFocusRectangle:CAShapeLayer? = nil
    
    fileprivate func _showFocusRectangleAtPoint(_ focusPoint: CGPoint, inLayer layer: CALayer) {
        
        if let lastFocusRectangle = lastFocusRectangle {
            
            lastFocusRectangle.removeFromSuperlayer()
            self.lastFocusRectangle = nil
        }
        
        let size = CGSize(width: 75, height: 75)
        let rect = CGRect(origin: CGPoint(x: focusPoint.x - size.width / 2.0, y: focusPoint.y - size.height / 2.0), size: size)
        
        let endPath = UIBezierPath(rect: rect)
        endPath.move(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.minY))
        endPath.addLine(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.minY + 5.0))
        endPath.move(to: CGPoint(x: rect.maxX, y: rect.minY + size.height / 2.0))
        endPath.addLine(to: CGPoint(x: rect.maxX - 5.0, y: rect.minY + size.height / 2.0))
        endPath.move(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.maxY))
        endPath.addLine(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.maxY - 5.0))
        endPath.move(to: CGPoint(x: rect.minX, y: rect.minY + size.height / 2.0))
        endPath.addLine(to: CGPoint(x: rect.minX + 5.0, y: rect.minY + size.height / 2.0))
        
        let startPath = UIBezierPath(cgPath: endPath.cgPath)
        let scaleAroundCenterTransform = CGAffineTransform(translationX: -focusPoint.x, y: -focusPoint.y).concatenating(CGAffineTransform(scaleX: 2.0, y: 2.0).concatenating(CGAffineTransform(translationX: focusPoint.x, y: focusPoint.y)))
        startPath.apply(scaleAroundCenterTransform)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = endPath.cgPath
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor(red:1, green:0.83, blue:0, alpha:0.95).cgColor
        shapeLayer.lineWidth = 1.0
        
        layer.addSublayer(shapeLayer)
        lastFocusRectangle = shapeLayer
        
        CATransaction.begin()
        
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut))
        
        CATransaction.setCompletionBlock() {
            if shapeLayer.superlayer != nil {
                shapeLayer.removeFromSuperlayer()
                self.lastFocusRectangle = nil
            }
        }
        
        let appearPathAnimation = CABasicAnimation(keyPath: "path")
        appearPathAnimation.fromValue = startPath.cgPath
        appearPathAnimation.toValue = endPath.cgPath
        shapeLayer.add(appearPathAnimation, forKey: "path")
        
        let appearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
        appearOpacityAnimation.fromValue = 0.0
        appearOpacityAnimation.toValue = 1.0
        shapeLayer.add(appearOpacityAnimation, forKey: "opacity")
        
        let disappearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
        disappearOpacityAnimation.fromValue = 1.0
        disappearOpacityAnimation.toValue = 0.0
        disappearOpacityAnimation.beginTime = CACurrentMediaTime() + 0.8
        disappearOpacityAnimation.fillMode = kCAFillModeForwards
        disappearOpacityAnimation.isRemovedOnCompletion = false
        shapeLayer.add(disappearOpacityAnimation, forKey: "opacity")
        
        CATransaction.commit()
    }
    
    
    // MARK: - CameraManager()
    
    fileprivate func _executeVideoCompletionWithURL(_ url: URL?, error: NSError?) {
        if let validCompletion = videoCompletion {
            validCompletion(url, error)
            videoCompletion = nil
        }
    }
    
    fileprivate func _getMovieOutput() -> AVCaptureMovieFileOutput {
        if let movieOutput = movieOutput, let connection = movieOutput.connection(with: AVMediaType.video),
            connection.isActive {
            return movieOutput
        }
        let newMoviewOutput = AVCaptureMovieFileOutput()
        newMoviewOutput.movieFragmentInterval = kCMTimeInvalid
        movieOutput = newMoviewOutput
        if let captureSession = captureSession {
            if captureSession.canAddOutput(newMoviewOutput) {
                captureSession.beginConfiguration()
                captureSession.addOutput(newMoviewOutput)
                captureSession.commitConfiguration()
            }
        }
        return newMoviewOutput
    }
    
    fileprivate func _getStillImageOutput() -> AVCaptureStillImageOutput {
        if let stillImageOutput = stillImageOutput, let connection = stillImageOutput.connection(with: AVMediaType.video),
            connection.isActive {
            return stillImageOutput
        }
        let newStillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput = newStillImageOutput
        if let captureSession = captureSession {
            if captureSession.canAddOutput(newStillImageOutput) {
                captureSession.beginConfiguration()
                captureSession.addOutput(newStillImageOutput)
                captureSession.commitConfiguration()
            }
        }
        return newStillImageOutput
    }
    
    @objc fileprivate func _orientationChanged() {
        var currentConnection: AVCaptureConnection?;
        switch cameraOutputMode {
        case .stillImage:
            currentConnection = stillImageOutput?.connection(with: AVMediaType.video)
        case .videoOnly, .videoWithMic:
            currentConnection = _getMovieOutput().connection(with: AVMediaType.video)
        }
        if let validPreviewLayer = previewLayer {
            if !shouldKeepViewAtOrientationChanges {
                if let validPreviewLayerConnection = validPreviewLayer.connection {
                    if validPreviewLayerConnection.isVideoOrientationSupported {
                        validPreviewLayerConnection.videoOrientation = _currentVideoOrientation()
                    }
                }
            }
            if let validOutputLayerConnection = currentConnection {
                if validOutputLayerConnection.isVideoOrientationSupported {
                    validOutputLayerConnection.videoOrientation = _currentVideoOrientation()
                }
            }
            if !shouldKeepViewAtOrientationChanges {
                DispatchQueue.main.async(execute: { () -> Void in
                    if let validEmbeddingView = self.embeddingView {
                        validPreviewLayer.frame = validEmbeddingView.bounds
                    }
                })
            }
        }
    }
    
    fileprivate func _currentVideoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return .portrait
        }
    }
    
    fileprivate func _canLoadCamera() -> Bool {
        let currentCameraState = _checkIfCameraIsAvailable()
        return currentCameraState == .ready || (currentCameraState == .notDetermined && showAccessPermissionPopupAutomatically)
    }
    
    fileprivate func _setupCamera(_ completion: @escaping () -> Void) {
        captureSession = AVCaptureSession()
        
        sessionQueue.async(execute: {
            if let validCaptureSession = self.captureSession {
                validCaptureSession.beginConfiguration()
                validCaptureSession.sessionPreset = AVCaptureSession.Preset.high
                self._updateCameraDevice(self.cameraDevice)
                self._setupOutputs()
                self._setupOutputMode(self.cameraOutputMode, oldCameraOutputMode: nil)
                self._setupPreviewLayer()
                validCaptureSession.commitConfiguration()
                self._updateFlashMode(self.flashMode)
                self._updateCameraQualityMode(self.cameraOutputQuality)
                validCaptureSession.startRunning()
                self._startFollowingDeviceOrientation()
                self.cameraIsSetup = true
                self._orientationChanged()
                
                completion()
            }
        })
    }
    
    fileprivate func _startFollowingDeviceOrientation() {
        if shouldRespondToOrientationChanges && !cameraIsObservingDeviceOrientation {
            NotificationCenter.default.addObserver(self, selector: #selector(CameraManager._orientationChanged), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
            cameraIsObservingDeviceOrientation = true
        }
    }
    
    fileprivate func _stopFollowingDeviceOrientation() {
        if cameraIsObservingDeviceOrientation {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
            cameraIsObservingDeviceOrientation = false
        }
    }
    
    fileprivate func _addPreviewLayerToView(_ view: UIView) {
        embeddingView = view
        attachZoom(view)
        attachFocus(view)
        
        DispatchQueue.main.async(execute: { () -> Void in
            guard let previewLayer = self.previewLayer else { return }
            previewLayer.frame = view.layer.bounds
            view.clipsToBounds = true
            view.layer.addSublayer(previewLayer)
        })
    }
    
    fileprivate func _setupMaxZoomScale() {
        var maxZoom = CGFloat(1.0)
        beginZoomScale = CGFloat(1.0)
        
        if cameraDevice == .back, let backCameraDevice = backCameraDevice  {
            maxZoom = backCameraDevice.activeFormat.videoMaxZoomFactor
        }
        else if cameraDevice == .front, let frontCameraDevice = frontCameraDevice {
            maxZoom = frontCameraDevice.activeFormat.videoMaxZoomFactor
        }
        
        maxZoomScale = maxZoom
    }
    
    fileprivate func _checkIfCameraIsAvailable() -> CameraState {
        let deviceHasCamera = UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.rear) || UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.front)
        if deviceHasCamera {
            let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
            let userAgreedToUseIt = authorizationStatus == .authorized
            if userAgreedToUseIt {
                return .ready
            } else if authorizationStatus == AVAuthorizationStatus.notDetermined {
                return .notDetermined
            } else {
                _show(NSLocalizedString("Camera access denied", comment:""), message:NSLocalizedString("You need to go to settings app and grant acces to the camera device to use it.", comment:""))
                return .accessDenied
            }
        } else {
            _show(NSLocalizedString("Camera unavailable", comment:""), message:NSLocalizedString("The device does not have a camera.", comment:""))
            return .noDeviceFound
        }
    }
    
    fileprivate func _setupOutputMode(_ newCameraOutputMode: CameraOutputMode, oldCameraOutputMode: CameraOutputMode?) {
        captureSession?.beginConfiguration()
        
        if let cameraOutputToRemove = oldCameraOutputMode {
            // remove current setting
            switch cameraOutputToRemove {
            case .stillImage:
                if let validStillImageOutput = stillImageOutput {
                    captureSession?.removeOutput(validStillImageOutput)
                }
            case .videoOnly, .videoWithMic:
                if let validMovieOutput = movieOutput {
                    captureSession?.removeOutput(validMovieOutput)
                }
                if cameraOutputToRemove == .videoWithMic {
                    _removeMicInput()
                }
            }
        }
        
        // configure new devices
        switch newCameraOutputMode {
        case .stillImage:
            if (stillImageOutput == nil) {
                _setupOutputs()
            }
            if let validStillImageOutput = stillImageOutput {
                if let captureSession = captureSession {
                    if captureSession.canAddOutput(validStillImageOutput) {
                        captureSession.addOutput(validStillImageOutput)
                    }
                }
            }
        case .videoOnly, .videoWithMic:
            let videoMovieOutput = _getMovieOutput()
            if let captureSession = captureSession {
                if captureSession.canAddOutput(videoMovieOutput) {
                    captureSession.addOutput(videoMovieOutput)
                }
            }
            
            if newCameraOutputMode == .videoWithMic {
                if let validMic = _deviceInputFromDevice(mic) {
                    captureSession?.addInput(validMic)
                }
            }
        }
        captureSession?.commitConfiguration()
        _updateCameraQualityMode(cameraOutputQuality)
        _orientationChanged()
    }
    
    fileprivate func _setupOutputs() {
        if (stillImageOutput == nil) {
            stillImageOutput = AVCaptureStillImageOutput()
        }
        if (movieOutput == nil) {
            movieOutput = AVCaptureMovieFileOutput()
            movieOutput?.movieFragmentInterval = kCMTimeInvalid
        }
        if library == nil {
            library = PHPhotoLibrary.shared()
        }
    }
    
    fileprivate func _setupPreviewLayer() {
        if let validCaptureSession = captureSession {
            previewLayer = AVCaptureVideoPreviewLayer(session: validCaptureSession)
            previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        }
    }
    
    /**
     Switches between the current and specified camera using a flip animation similar to the one used in the iOS stock camera app
     */
    
    fileprivate var cameraTransitionView: UIView?
    fileprivate var transitionAnimating = false
    
    open func _doFlipAnimation() {
        
        if transitionAnimating {
            return
        }
        
        if let validEmbeddingView = embeddingView {
            if let validPreviewLayer = previewLayer {
                
                var tempView = UIView()
                
                if CameraManager._blurSupported() {
                    
                    let blurEffect = UIBlurEffect(style: .light)
                    tempView = UIVisualEffectView(effect: blurEffect)
                    tempView.frame = validEmbeddingView.bounds
                }
                else {
                    
                    tempView = UIView(frame: validEmbeddingView.bounds)
                    tempView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                }
                
                validEmbeddingView.insertSubview(tempView, at: Int(validPreviewLayer.zPosition + 1))
                
                cameraTransitionView = validEmbeddingView.snapshotView(afterScreenUpdates: true)
                
                if let cameraTransitionView = cameraTransitionView {
                    validEmbeddingView.insertSubview(cameraTransitionView, at: Int(validEmbeddingView.layer.zPosition + 1))
                }
                tempView.removeFromSuperview()
                
                transitionAnimating = true
                
                validPreviewLayer.opacity = 0.0
                
                DispatchQueue.main.async() {
                    self._flipCameraTransitionView()
                }
            }
        }
    }
    
    // MARK: - CameraLocationManager()
    
    fileprivate class CameraLocationManager: NSObject, CLLocationManagerDelegate {
        var locationManager = CLLocationManager()
        var latestLocation: CLLocation?
        
        override init() {
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestWhenInUseAuthorization()
        }
        
        func startUpdatingLocation() {
            locationManager.startUpdatingLocation()
        }
        
        func stopUpdatingLocation() {
            locationManager.stopUpdatingLocation()
        }
        
        // MARK: - CLLocationManagerDelegate
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            // Pick the location with best (= smallest value) horizontal accuracy
            latestLocation = locations.sorted { $0.horizontalAccuracy < $1.horizontalAccuracy }.first
        }
        
        func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                locationManager.startUpdatingLocation()
            } else {
                locationManager.stopUpdatingLocation()
            }
        }
    }
    
    // Determining whether the current device actually supports blurring
    // As seen on: http://stackoverflow.com/a/29997626/2269387
    fileprivate class func _blurSupported() -> Bool {
        var supported = Set<String>()
        supported.insert("iPad")
        supported.insert("iPad1,1")
        supported.insert("iPhone1,1")
        supported.insert("iPhone1,2")
        supported.insert("iPhone2,1")
        supported.insert("iPhone3,1")
        supported.insert("iPhone3,2")
        supported.insert("iPhone3,3")
        supported.insert("iPod1,1")
        supported.insert("iPod2,1")
        supported.insert("iPod2,2")
        supported.insert("iPod3,1")
        supported.insert("iPod4,1")
        supported.insert("iPad2,1")
        supported.insert("iPad2,2")
        supported.insert("iPad2,3")
        supported.insert("iPad2,4")
        supported.insert("iPad3,1")
        supported.insert("iPad3,2")
        supported.insert("iPad3,3")
        
        return !supported.contains(_hardwareString())
    }
    
    fileprivate class func _hardwareString() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let deviceName = String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)!.trimmingCharacters(in: .controlCharacters)
        return deviceName
    }
    
    fileprivate func _flipCameraTransitionView() {
        
        if let cameraTransitionView = cameraTransitionView {
            
            UIView.transition(with: cameraTransitionView,
                              duration: 0.5,
                              options: UIViewAnimationOptions.transitionFlipFromLeft,
                              animations: nil,
                              completion: { (finished) -> Void in
                                self._removeCameraTransistionView()
            })
        }
    }
    
    
    fileprivate func _removeCameraTransistionView() {
        
        if let cameraTransitionView = cameraTransitionView {
            if let validPreviewLayer = previewLayer {
                
                validPreviewLayer.opacity = 1.0
            }
            
            UIView.animate(withDuration: 0.5,
                           animations: { () -> Void in
                            
                            cameraTransitionView.alpha = 0.0
                            
            }, completion: { (finished) -> Void in
                
                self.transitionAnimating = false
                
                cameraTransitionView.removeFromSuperview()
                self.cameraTransitionView = nil
            })
        }
    }
    
    fileprivate func _updateCameraDevice(_ deviceType: CameraDevice) {
        if let validCaptureSession = captureSession {
            validCaptureSession.beginConfiguration()
            defer { validCaptureSession.commitConfiguration() }
            let inputs: [AVCaptureInput] = validCaptureSession.inputs
            
            for input in inputs {
                if let deviceInput = input as? AVCaptureDeviceInput {
                    validCaptureSession.removeInput(deviceInput)
                }
            }
            
            switch cameraDevice {
            case .front:
                if hasFrontCamera {
                    if let validFrontDevice = _deviceInputFromDevice(frontCameraDevice) {
                        if !inputs.contains(validFrontDevice) {
                            validCaptureSession.addInput(validFrontDevice)
                        }
                    }
                }
            case .back:
                if let validBackDevice = _deviceInputFromDevice(backCameraDevice) {
                    if !inputs.contains(validBackDevice) {
                        validCaptureSession.addInput(validBackDevice)
                    }
                }
            }
        }
    }
    
    fileprivate func _updateFlashMode(_ flashMode: CameraFlashMode) {
        captureSession?.beginConfiguration()
        defer { captureSession?.commitConfiguration() }
        for captureDevice in AVCaptureDevice.videoDevices  {
            guard let avFlashMode = AVCaptureDevice.FlashMode(rawValue: flashMode.rawValue) else { continue }
            if (captureDevice.isFlashModeSupported(avFlashMode)) {
                do {
                    try captureDevice.lockForConfiguration()
                } catch {
                    return
                }
                captureDevice.flashMode = avFlashMode
                captureDevice.unlockForConfiguration()
            }
        }

    }
    
    fileprivate func _performShutterAnimation(_ completion: (() -> Void)?) {
        
        if let validPreviewLayer = previewLayer {
            
            DispatchQueue.main.async {
            
                let duration = 0.1
                
                CATransaction.begin()
                
                if let completion = completion {
                    
                    CATransaction.setCompletionBlock(completion)
                }
                
                let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
                fadeOutAnimation.fromValue = 1.0
                fadeOutAnimation.toValue = 0.0
                validPreviewLayer.add(fadeOutAnimation, forKey: "opacity")
                
                let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
                fadeInAnimation.fromValue = 0.0
                fadeInAnimation.toValue = 1.0
                fadeInAnimation.beginTime = CACurrentMediaTime() + duration * 2.0
                validPreviewLayer.add(fadeInAnimation, forKey: "opacity")
                
                CATransaction.commit()
            }
        }
    }
    
    fileprivate func _updateCameraQualityMode(_ newCameraOutputQuality: CameraOutputQuality) {
        if let validCaptureSession = captureSession {
            var sessionPreset = AVCaptureSession.Preset.low
            switch (newCameraOutputQuality) {
            case CameraOutputQuality.low:
                sessionPreset = AVCaptureSession.Preset.low
            case CameraOutputQuality.medium:
                sessionPreset = AVCaptureSession.Preset.medium
            case CameraOutputQuality.high:
                if cameraOutputMode == .stillImage {
                    sessionPreset = AVCaptureSession.Preset.photo
                } else {
                    sessionPreset = AVCaptureSession.Preset.high
                }
            }
            if validCaptureSession.canSetSessionPreset(sessionPreset) {
                validCaptureSession.beginConfiguration()
                validCaptureSession.sessionPreset = sessionPreset
                validCaptureSession.commitConfiguration()
            } else {
                _show(NSLocalizedString("Preset not supported", comment:""), message: NSLocalizedString("Camera preset not supported. Please try another one.", comment:""))
            }
        } else {
            _show(NSLocalizedString("Camera error", comment:""), message: NSLocalizedString("No valid capture session found, I can't take any pictures or videos.", comment:""))
        }
    }
    
    fileprivate func _removeMicInput() {
        guard let inputs = captureSession?.inputs else { return }
        
        for input in inputs {
            if let deviceInput = input as? AVCaptureDeviceInput {
                if deviceInput.device == mic {
                    captureSession?.removeInput(deviceInput)
                    break;
                }
            }
        }
    }
    
    fileprivate func _show(_ title: String, message: String) {
        if showErrorsToUsers {
            DispatchQueue.main.async(execute: { () -> Void in
                self.showErrorBlock(title, message)
            })
        }
    }
    
    fileprivate func _deviceInputFromDevice(_ device: AVCaptureDevice?) -> AVCaptureDeviceInput? {
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        } catch let outError {
            _show(NSLocalizedString("Device setup error occured", comment:""), message: "\(outError)")
            return nil
        }
    }
    
    deinit {
        stopAndRemoveCaptureSession()
        _stopFollowingDeviceOrientation()
    }
}


fileprivate extension AVCaptureDevice {
    fileprivate static var videoDevices: [AVCaptureDevice] {
        return AVCaptureDevice.devices(for: AVMediaType.video)
    }
}
