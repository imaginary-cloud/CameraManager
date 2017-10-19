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
public class CameraManager: NSObject, AVCaptureFileOutputRecordingDelegate, UIGestureRecognizerDelegate {
    
    // MARK: - Public properties
    
    /// Capture session to customize camera settings.
    public var captureSession: AVCaptureSession?
    
    /// Property to determine if the manager should show the error for the user. If you want to show the errors yourself set this to false. If you want to add custom error UI set showErrorBlock property. Default value is false.
    public var showErrorsToUsers = false
    
    /// Property to determine if the manager should show the camera permission popup immediatly when it's needed or you want to show it manually. Default value is true. Be carful cause using the camera requires permission, if you set this value to false and don't ask manually you won't be able to use the camera.
    public var showAccessPermissionPopupAutomatically = true
    
    /// A block creating UI to present error message to the user. This can be customised to be presented on the Window root view controller, or to pass in the viewController which will present the UIAlertController, for example.
    public var showErrorBlock:(_ erTitle: String, _ erMessage: String) -> Void = { (erTitle: String, erMessage: String) -> Void in
        
        //        var alertController = UIAlertController(title: erTitle, message: erMessage, preferredStyle: .Alert)
        //        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (alertAction) -> Void in  }))
        //
        //        if let topController = UIApplication.sharedApplication().keyWindow?.rootViewController {
        //            topController.presentViewController(alertController, animated: true, completion:nil)
        //        }
    }
    
    /// Property to determine if manager should write the resources to the phone library. Default value is true.
    public var writeFilesToPhoneLibrary = true
    
    /// Property to determine if manager should follow device orientation. Default value is true.
    public var shouldRespondToOrientationChanges = true {
        didSet {
            if shouldRespondToOrientationChanges {
                _startFollowingDeviceOrientation()
            } else {
                _stopFollowingDeviceOrientation()
            }
        }
    }
    
    /// The Bool property to determine if the camera is ready to use.
    public var cameraIsReady: Bool {
        get {
            return cameraIsSetup
        }
    }
    
    /// The Bool property to determine if current device has front camera.
    public var hasFrontCamera: Bool = {
        let devices = AVCaptureDevice.devices(for: AVMediaType.video)
        for  device in devices  {
            let captureDevice = device
            if (captureDevice.position == .front) {
                return true
            }
        }
        return false
    }()
    
    /// The Bool property to determine if current device has flash.
    public var hasFlash: Bool = {
        let devices = AVCaptureDevice.devices(for: AVMediaType.video)
        for  device in devices  {
            let captureDevice = device
            if (captureDevice.position == .back) {
                return captureDevice.hasFlash
            }
        }
        return false
    }()
    
    /// Property to change camera device between front and back.
    public var cameraDevice: CameraDevice = .back {
        didSet {
            if cameraIsSetup {
                if cameraDevice != oldValue {
                    _updateCameraDevice(deviceType: cameraDevice)
                    _setupMaxZoomScale()
                    _zoom(scale: 0)
                }
            }
        }
    }
    
    /// Property to change camera flash mode.
    public var flashMode: CameraFlashMode = .off {
        didSet {
            if cameraIsSetup {
                if flashMode != oldValue {
                    _updateFlasMode(flashMode: flashMode)
                }
            }
        }
    }
    
    /// Property to change camera output quality.
    public var cameraOutputQuality: CameraOutputQuality = .high {
        didSet {
            if cameraIsSetup {
                if cameraOutputQuality != oldValue {
                    _updateCameraQualityMode(newCameraOutputQuality: cameraOutputQuality)
                }
            }
        }
    }
    
    /// Property to change camera output.
    public var cameraOutputMode: CameraOutputMode = .stillImage {
        didSet {
            if cameraIsSetup {
                if cameraOutputMode != oldValue {
                    _setupOutputMode(newCameraOutputMode: cameraOutputMode, oldCameraOutputMode: oldValue)
                }
                _setupMaxZoomScale()
                _zoom(scale: 0)
            }
        }
    }
    
    /// Property to check video recording duration when in progress
    public var recordedDuration : CMTime { return movieOutput?.recordedDuration ?? kCMTimeZero }
    
    /// Property to check video recording file size when in progress
    public var recordedFileSize : Int64 { return movieOutput?.recordedFileSize ?? 0 }
    
    
    // MARK: - Private properties
    
    private weak var embeddingView: UIView?
    private var videoCompletion: ((_ videoURL: URL?, _ error: Error?) -> Void)?
    
    private var sessionQueue: DispatchQueue = DispatchQueue(label: "CameraSessionQueue", qos: .userInteractive)
    
    private lazy var frontCameraDevice: AVCaptureDevice? = {
        let devices = AVCaptureDevice.devices(for: AVMediaType.video)
        return devices.filter{$0.position == .front}.first
    }()
    
    private lazy var backCameraDevice: AVCaptureDevice? = {
        let devices = AVCaptureDevice.devices(for: AVMediaType.video)
        return devices.filter{$0.position == .back}.first
    }()
    
    private lazy var mic: AVCaptureDevice? = {
        return AVCaptureDevice.default(for: AVMediaType.audio)
    }()
    
    private var stillImageOutput: AVCaptureStillImageOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var library: ALAssetsLibrary?
    
    private var cameraIsSetup = false
    private var cameraIsObservingDeviceOrientation = false
    
    private var zoomScale       = CGFloat(1.0)
    private var beginZoomScale  = CGFloat(1.0)
    private var maxZoomScale    = CGFloat(1.0)
    
    private var tempFilePath: URL = {
        let tempPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempMovie").appendingPathExtension("mp4").absoluteString
        if FileManager.default.fileExists(atPath: tempPath) {
            do {
                try FileManager.default.removeItem(atPath: tempPath)
            } catch { }
        }
        return URL(string: tempPath)!
    }()
    
    
    // MARK: - CameraManager
    
    /**
     Inits a capture session and adds a preview layer to the given view. Preview layer bounds will automaticaly be set to match given view. Default session is initialized with still image output.
     
     :param: view The view you want to add the preview layer to
     :param: cameraOutputMode The mode you want capturesession to run image / video / video and microphone
     :param: completion Optional completion block
     
     :returns: Current state of the camera: Ready / AccessDenied / NoDeviceFound / NotDetermined.
     */
    @discardableResult
    public func addPreviewLayerToView(_ view: UIView) -> CameraState {
        return addPreviewLayerToView(view, newCameraOutputMode: cameraOutputMode)
    }
    
    @discardableResult
    public func addPreviewLayerToView(_ view: UIView, newCameraOutputMode: CameraOutputMode) -> CameraState {
        return addLayerPreviewToView(view: view, newCameraOutputMode: newCameraOutputMode, completion: nil)
    }
    
    @available(*, unavailable, renamed: "addLayerPreviewToView")
    public func addPreviewLayerToView(view: UIView, newCameraOutputMode: CameraOutputMode, completition: (() -> Void)?) -> CameraState {
        return addLayerPreviewToView(view: view, newCameraOutputMode: newCameraOutputMode, completion: completition)
    }
    
    public func addLayerPreviewToView(view: UIView, newCameraOutputMode: CameraOutputMode, completion: (() -> Void)?) -> CameraState {
        if _canLoadCamera() {
            if let _ = embeddingView {
                if let validPreviewLayer = previewLayer {
                    validPreviewLayer.removeFromSuperlayer()
                }
            }
            if cameraIsSetup {
                _addPreviewLayerToView(view: view)
                cameraOutputMode = newCameraOutputMode
                if let validCompletion = completion {
                    validCompletion()
                }
            } else {
                _setupCamera(completion: {
                    self._addPreviewLayerToView(view: view)
                    self.cameraOutputMode = newCameraOutputMode
                    if let validCompletion = completion {
                        validCompletion()
                    }
                })
            }
        }
        return _checkIfCameraIsAvailable()
    }
    
    @available(*, unavailable, renamed: "askUserForCameraPermission")
    public func askUserForCameraPermissions(completition: (Bool) -> Void) {}
    
    /**
     Asks the user for camera permissions. Only works if the permissions are not yet determined. Note that it'll also automaticaly ask about the microphone permissions if you selected VideoWithMic output.
     
     :param: completion Completion block with the result of permission request
     */
    public func askUserForCameraPermission(completion: @escaping ((Bool)  -> Void)) {
        AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (alowedAccess) -> Void in
            if self.cameraOutputMode == .videoWithMic {
                AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: { (alowedAccess) in
                    DispatchQueue.main.async {
                        completion(alowedAccess)
                    }
                })
            } else {
                DispatchQueue.main.async {
                    completion(alowedAccess)
                }
            }
        })
    }
    
    /**
     Stops running capture session but all setup devices, inputs and outputs stay for further reuse.
     */
    public func stopCaptureSession() {
        captureSession?.stopRunning()
        _stopFollowingDeviceOrientation()
    }
    
    /**
     Resumes capture session.
     */
    public func resumeCaptureSession() {
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
                        self._addPreviewLayerToView(view: validEmbeddingView)
                    }
                    self._startFollowingDeviceOrientation()
                }
            }
        }
    }
    
    /**
     Stops running capture session and removes all setup devices, inputs and outputs.
     */
    public func stopAndRemoveCaptureSession() {
        stopCaptureSession()
        cameraDevice = .back
        cameraIsSetup = false
        previewLayer = nil
        captureSession = nil
        frontCameraDevice = nil
        backCameraDevice = nil
        mic = nil
        stillImageOutput = nil
        movieOutput = nil
    }
    
    @available(*, unavailable, renamed: "capturePictureWithCompletion")
    public func capturePictureWithCompletition(imageCompletition: (UIImage?, Error?) -> Void) {}
    
    /**
     Captures still image from currently running capture session.
     
     :param: imageCompletion Completion block containing the captured UIImage
     */
    public func capturePictureWithCompletion(imageCompletion: @escaping (UIImage?, Error?) -> Void) {
        self.capturePictureDataWithCompletion { data, error in
            
            guard error == nil, let imageData = data else {
                imageCompletion(nil, error)
                return
            }
            
            if self.writeFilesToPhoneLibrary == true, let library = self.library  {
                
                library.writeImageData(toSavedPhotosAlbum: imageData as Data!, metadata:nil) { picUrl, error in
                    guard error != nil else {
                        return
                    }
                    DispatchQueue.main.async {
                        self._show(title: NSLocalizedString("Error", comment:""), message: error?.localizedDescription ?? "")
                    }
                }
                
            }
            imageCompletion(UIImage(data: imageData), nil)
        }
        
    }
    
    @available(*, unavailable, renamed: "capturePictureWithCompletion")
    public func capturePictureDataWithCompletition(imageCompletition: (Data?, Error?) -> Void) {}
    
    /**
     Captures still image from currently running capture session.
     
     :param: imageCompletion Completion block containing the captured imageData
     */
    public func capturePictureDataWithCompletion(imageCompletion: @escaping (Data?, Error?) -> Void) {
        
        guard cameraIsSetup else {
            _show(title: NSLocalizedString("No capture session setup", comment:""), message: NSLocalizedString("I can't take any picture", comment:""))
            return
        }
        
        guard cameraOutputMode == .stillImage else {
            _show(title: NSLocalizedString("Capture session output mode video", comment:""), message: NSLocalizedString("I can't take any picture", comment:""))
            return
        }
        
        self.sessionQueue.async {
            guard let output = self._getStillImageOutput().connection(with: AVMediaType.video) else { return }
            self._getStillImageOutput().captureStillImageAsynchronously(from: output) { [unowned self] sample, error in
                guard error == nil, let sample = sample else {
                    DispatchQueue.main.async {
                        self._show(title: NSLocalizedString("Error", comment:""), message: error?.localizedDescription ?? "")
                    }
                    imageCompletion(nil, error)
                    return
                }
                
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sample)
                
                
                imageCompletion(imageData, nil)
                
            }
        }
        
    }
    
    /**
     Starts recording a video with or without voice as in the session preset.
     */
    public func startRecordingVideo() {
        if cameraOutputMode != .stillImage {
            _getMovieOutput().startRecording(to: tempFilePath, recordingDelegate: self)
        } else {
            _show(title: NSLocalizedString("Capture session output still image", comment:""), message: NSLocalizedString("I can only take pictures", comment:""))
        }
    }
    
    @available(*, unavailable, renamed: "stopVideoRecording")
    public func stopRecordingVideo(completition:(URL?, Error?) -> Void) {}
    
    /**
     Stop recording a video. Save it to the cameraRoll and give back the url.
     */
    public func stopVideoRecording(completion: @escaping ((URL?, Error?) -> Void)) {
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
    public func currentCameraStatus() -> CameraState {
        return _checkIfCameraIsAvailable()
    }
    
    /**
     Change current flash mode to next value from available ones.
     
     :returns: Current flash mode: Off / On / Auto
     */
    public func changeFlashMode() -> CameraFlashMode {
        flashMode = CameraFlashMode(rawValue: (flashMode.rawValue+1)%3)!
        return flashMode
    }
    
    /**
     Change current output quality mode to next value from available ones.
     
     :returns: Current quality mode: Low / Medium / High
     */
    public func changeQualityMode() -> CameraOutputQuality {
        cameraOutputQuality = CameraOutputQuality(rawValue: (cameraOutputQuality.rawValue+1)%3)!
        return cameraOutputQuality
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate
    
    public func captureOutput(captureOutput: AVCaptureFileOutput, didStartRecordingToOutputFileAtURL fileURL: URL, fromConnections connections: [AnyObject]) {
        captureSession?.beginConfiguration()
        if flashMode != .off {
            _updateTorch(flashMode: flashMode)
        }
        captureSession?.commitConfiguration()
    }
    
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        _updateTorch(flashMode: .off)
        if (error != nil) {
            _show(title: NSLocalizedString("Unable to save video to the iPhone", comment:""), message: error?.localizedDescription ?? "")
        } else {
            if let validLibrary = library {
                if writeFilesToPhoneLibrary {
                    validLibrary.writeVideoAtPath(toSavedPhotosAlbum: outputFileURL, completionBlock: { (assetURL: URL?, error: Error?) -> Void in
                        if (error != nil) {
                            self._show(title: NSLocalizedString("Unable to save video to the iPhone.", comment:""), message: error!.localizedDescription)
                            self._executeVideoCompletionWithURL(url: nil, error: error)
                        } else {
                            if let validAssetURL = assetURL {
                                self._executeVideoCompletionWithURL(url: validAssetURL, error: error)
                            }
                        }
                    })
                } else {
                    _executeVideoCompletionWithURL(url: outputFileURL, error: error)
                }
            }
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    private func attachZoom(view: UIView) {
        DispatchQueue.main.async {
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(CameraManager._zoomStart(recognizer:)))
            view.addGestureRecognizer(pinch)
            pinch.delegate = self
        }
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.isKind(of: UIPinchGestureRecognizer.self) {
            beginZoomScale = zoomScale;
        }
        
        return true
    }
    
    @objc
    private func _zoomStart(recognizer: UIPinchGestureRecognizer) {
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
            _zoom(scale: recognizer.scale)
        }
    }
    
    private func _zoom(scale: CGFloat) {
        do {
            let captureDevice = AVCaptureDevice.devices().first
            try captureDevice?.lockForConfiguration()
            
            zoomScale = max(1.0, min(beginZoomScale * scale, maxZoomScale))
            
            captureDevice?.videoZoomFactor = zoomScale
            
            captureDevice?.unlockForConfiguration()
            
        } catch {
            print("Error locking configuration")
        }
    }
    
    // MARK: - CameraManager()
    
    private func _updateTorch(flashMode: CameraFlashMode) {
        captureSession?.beginConfiguration()
        let devices = AVCaptureDevice.devices(for: AVMediaType.video)
        for  device in devices  {
            let captureDevice = device
            if (captureDevice.position == AVCaptureDevice.Position.back) {
                let avTorchMode = AVCaptureDevice.TorchMode(rawValue: flashMode.rawValue)
                if (captureDevice.isTorchModeSupported(avTorchMode!)) {
                    do {
                        try captureDevice.lockForConfiguration()
                    } catch {
                        return;
                    }
                    captureDevice.torchMode = avTorchMode!
                    captureDevice.unlockForConfiguration()
                }
            }
        }
        captureSession?.commitConfiguration()
    }
    
    
    private func _executeVideoCompletionWithURL(url: URL?, error: Error?) {
        if let validCompletion = videoCompletion {
            validCompletion(url, error)
            videoCompletion = nil
        }
    }
    
    private func _getMovieOutput() -> AVCaptureMovieFileOutput {
        var shouldReinitializeMovieOutput = movieOutput == nil
        if !shouldReinitializeMovieOutput {
            if let connection = movieOutput!.connection(with: AVMediaType.video) {
                shouldReinitializeMovieOutput = shouldReinitializeMovieOutput || !connection.isActive
            }
        }
        
        if shouldReinitializeMovieOutput {
            movieOutput = AVCaptureMovieFileOutput()
            movieOutput!.movieFragmentInterval = kCMTimeInvalid
            
            if let captureSession = captureSession {
                if captureSession.canAddOutput(movieOutput!) {
                    captureSession.beginConfiguration()
                    captureSession.addOutput(movieOutput!)
                    captureSession.commitConfiguration()
                }
            }
        }
        return movieOutput!
    }
    
    private func _getStillImageOutput() -> AVCaptureStillImageOutput {
        var shouldReinitializeStillImageOutput = stillImageOutput == nil
        if !shouldReinitializeStillImageOutput {
            if let connection = stillImageOutput!.connection(with: AVMediaType.video) {
                shouldReinitializeStillImageOutput = shouldReinitializeStillImageOutput || !connection.isActive
            }
        }
        if shouldReinitializeStillImageOutput {
            stillImageOutput = AVCaptureStillImageOutput()
            
            if let captureSession = captureSession {
                if captureSession.canAddOutput(stillImageOutput!) {
                    captureSession.beginConfiguration()
                    captureSession.addOutput(stillImageOutput!)
                    captureSession.commitConfiguration()
                }
            }
        }
        return stillImageOutput!
    }
    
    @objc private func _orientationChanged() {
        var currentConnection: AVCaptureConnection?;
        switch cameraOutputMode {
        case .stillImage:
            currentConnection = stillImageOutput?.connection(with: AVMediaType.video)
        case .videoOnly, .videoWithMic:
            currentConnection = _getMovieOutput().connection(with: AVMediaType.video)
        }
        if let validPreviewLayer = previewLayer {
            if let validPreviewLayerConnection = validPreviewLayer.connection {
                if validPreviewLayerConnection.isVideoOrientationSupported {
                    validPreviewLayerConnection.videoOrientation = _currentVideoOrientation()
                }
            }
            if let validOutputLayerConnection = currentConnection {
                if validOutputLayerConnection.isVideoOrientationSupported {
                    validOutputLayerConnection.videoOrientation = _currentVideoOrientation()
                }
            }
            DispatchQueue.main.async {
                if let validEmbeddingView = self.embeddingView {
                    validPreviewLayer.frame = validEmbeddingView.bounds
                }
            }
        }
    }
    
    private func _currentVideoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return .portrait
        }
    }
    
    private func _canLoadCamera() -> Bool {
        let currentCameraState = _checkIfCameraIsAvailable()
        return currentCameraState == .ready || (currentCameraState == .notDetermined && showAccessPermissionPopupAutomatically)
    }
    
    private func _setupCamera(completion: @escaping (() -> Void)) {
        captureSession = AVCaptureSession()
        
        self.sessionQueue.async {
            if let validCaptureSession = self.captureSession {
                validCaptureSession.beginConfiguration()
                validCaptureSession.sessionPreset = AVCaptureSession.Preset.high
                self._updateCameraDevice(deviceType: self.cameraDevice)
                self._setupOutputs()
                self._setupOutputMode(newCameraOutputMode: self.cameraOutputMode, oldCameraOutputMode: nil)
                self._setupPreviewLayer()
                validCaptureSession.commitConfiguration()
                self._updateFlasMode(flashMode: self.flashMode)
                self._updateCameraQualityMode(newCameraOutputQuality: self.cameraOutputQuality)
                validCaptureSession.startRunning()
                self._startFollowingDeviceOrientation()
                self.cameraIsSetup = true
                self._orientationChanged()
                
                completion()
            }
        }
    }
    
    private func _startFollowingDeviceOrientation() {
        if shouldRespondToOrientationChanges && !cameraIsObservingDeviceOrientation {
            NotificationCenter.default.addObserver(self, selector: #selector(CameraManager._orientationChanged), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
            cameraIsObservingDeviceOrientation = true
        }
    }
    
    private func _stopFollowingDeviceOrientation() {
        if cameraIsObservingDeviceOrientation {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
            cameraIsObservingDeviceOrientation = false
        }
    }
    
    private func _addPreviewLayerToView(view: UIView) {
        embeddingView = view
        attachZoom(view: view)
        DispatchQueue.main.async {
            guard let _ = self.previewLayer else {
                return
            }
            self.previewLayer!.frame = view.layer.bounds
            view.clipsToBounds = true
            view.layer.addSublayer(self.previewLayer!)
        }
    }
    
    private func _setupMaxZoomScale() {
        var maxZoom = CGFloat(1.0)
        beginZoomScale = CGFloat(1.0)
        
        if cameraDevice == .back {
            maxZoom = (backCameraDevice?.activeFormat.videoMaxZoomFactor)!
        }
        else if cameraDevice == .front {
            maxZoom = (frontCameraDevice?.activeFormat.videoMaxZoomFactor)!
        }
        
        maxZoomScale = maxZoom
    }
    
    private func _checkIfCameraIsAvailable() -> CameraState {
        let deviceHasCamera = UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.rear) || UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.front)
        if deviceHasCamera {
            let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
            let userAgreedToUseIt = authorizationStatus == .authorized
            if userAgreedToUseIt {
                return .ready
            } else if authorizationStatus == AVAuthorizationStatus.notDetermined {
                return .notDetermined
            } else {
                _show(title: NSLocalizedString("Camera access denied", comment:""), message: NSLocalizedString("You need to go to settings app and grant acces to the camera device to use it.", comment:""))
                return .accessDenied
            }
        } else {
            _show(title: NSLocalizedString("Camera unavailable", comment:""), message:NSLocalizedString("The device does not have a camera.", comment:""))
            return .noDeviceFound
        }
    }
    
    private func _setupOutputMode(newCameraOutputMode: CameraOutputMode, oldCameraOutputMode: CameraOutputMode?) {
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
            captureSession?.addOutput(_getMovieOutput())
            
            if newCameraOutputMode == .videoWithMic {
                if let validMic = _deviceInputFromDevice(device: mic) {
                    captureSession?.addInput(validMic)
                }
            }
        }
        captureSession?.commitConfiguration()
        _updateCameraQualityMode(newCameraOutputQuality: cameraOutputQuality)
        _orientationChanged()
    }
    
    private func _setupOutputs() {
        if (stillImageOutput == nil) {
            stillImageOutput = AVCaptureStillImageOutput()
        }
        if (movieOutput == nil) {
            movieOutput = AVCaptureMovieFileOutput()
            movieOutput!.movieFragmentInterval = kCMTimeInvalid
        }
        if library == nil {
            library = ALAssetsLibrary()
        }
    }
    
    private func _setupPreviewLayer() {
        if let validCaptureSession = captureSession {
            previewLayer = AVCaptureVideoPreviewLayer(session: validCaptureSession)
            previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        }
    }
    
    private func _updateCameraDevice(deviceType: CameraDevice) {
        if let validCaptureSession = captureSession {
            validCaptureSession.beginConfiguration()
            let inputs = validCaptureSession.inputs
            
            for input in inputs {
                if let deviceInput = input as? AVCaptureDeviceInput {
                    if deviceInput.device == backCameraDevice && cameraDevice == .front {
                        validCaptureSession.removeInput(deviceInput)
                        break;
                    } else if deviceInput.device == frontCameraDevice && cameraDevice == .back {
                        validCaptureSession.removeInput(deviceInput)
                        break;
                    }
                }
            }
            switch cameraDevice {
            case .front:
                if hasFrontCamera {
                    if let validFrontDevice = _deviceInputFromDevice(device: frontCameraDevice) {
                        if !inputs.contains(validFrontDevice) {
                            validCaptureSession.addInput(validFrontDevice)
                        }
                    }
                }
            case .back:
                if let validBackDevice = _deviceInputFromDevice(device: backCameraDevice) {
                    if !inputs.contains(validBackDevice) {
                        validCaptureSession.addInput(validBackDevice)
                    }
                }
            }
            validCaptureSession.commitConfiguration()
        }
    }
    
    private func _updateFlasMode(flashMode: CameraFlashMode) {
        captureSession?.beginConfiguration()
        let devices = AVCaptureDevice.devices(for: AVMediaType.video)
        for  device in devices  {
            let captureDevice = device
            if (captureDevice.position == AVCaptureDevice.Position.back) {
                let avFlashMode = AVCaptureDevice.FlashMode(rawValue: flashMode.rawValue)
                if (captureDevice.isFlashModeSupported(avFlashMode!)) {
                    do {
                        try captureDevice.lockForConfiguration()
                    } catch {
                        return
                    }
                    captureDevice.flashMode = avFlashMode!
                    captureDevice.unlockForConfiguration()
                }
            }
        }
        captureSession?.commitConfiguration()
    }
    
    private func _updateCameraQualityMode(newCameraOutputQuality: CameraOutputQuality) {
        if let validCaptureSession = captureSession {
            var sessionPreset: AVCaptureSession.Preset = .low
            switch (newCameraOutputQuality) {
            case .low:
                sessionPreset = .low
            case .medium:
                sessionPreset = .medium
            case .high:
                if cameraOutputMode == .stillImage {
                    sessionPreset = .photo
                } else {
                    sessionPreset = .high
                }
            }
            if validCaptureSession.canSetSessionPreset(sessionPreset) {
                validCaptureSession.beginConfiguration()
                validCaptureSession.sessionPreset = sessionPreset
                validCaptureSession.commitConfiguration()
            } else {
                _show(title: NSLocalizedString("Preset not supported", comment:""), message: NSLocalizedString("Camera preset not supported. Please try another one.", comment:""))
            }
        } else {
            _show(title: NSLocalizedString("Camera error", comment:""), message: NSLocalizedString("No valid capture session found, I can't take any pictures or videos.", comment:""))
        }
    }
    
    private func _removeMicInput() {
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
    
    private func _show(title: String, message: String) {
        if showErrorsToUsers {
            DispatchQueue.main.async {
                self.showErrorBlock(title, message)
            }
        }
    }
    
    private func _deviceInputFromDevice(device: AVCaptureDevice?) -> AVCaptureDeviceInput? {
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        } catch let outError {
            _show(title: NSLocalizedString("Device setup error occured", comment:""), message: "\(outError)")
            return nil
        }
    }
    
    deinit {
        stopAndRemoveCaptureSession()
        _stopFollowingDeviceOrientation()
    }
}
