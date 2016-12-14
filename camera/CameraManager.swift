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
	
	// The layer that previews the camera feed
	open var previewLayer: AVCaptureVideoPreviewLayer?
	
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
	
	/// The Bool property to determine if the camera is ready to use.
	open var cameraIsReady: Bool {
		get {
			return cameraIsSetup
		}
	}
	
	/// The Bool property to determine if current device has front camera.
	open var hasFrontCamera: Bool = {
		let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
		for  device in devices!  {
			let captureDevice = device as! AVCaptureDevice
			if (captureDevice.position == .front) {
				return true
			}
		}
		return false
	}()
	
	/// The Bool property to determine if current device has flash.
	open var hasFlash: Bool = {
		let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
		for  device in devices!  {
			let captureDevice = device as! AVCaptureDevice
			if (captureDevice.position == .back) {
				return captureDevice.hasFlash
			}
		}
		return false
	}()
	
	/// Property to change camera device between front and back.
	open var cameraDevice = CameraDevice.back {
		didSet {
			if cameraIsSetup {
				if cameraDevice != oldValue {
					_updateCameraDevice(cameraDevice)
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
					_updateFlasMode(flashMode)
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
	
	
	// MARK: - Private properties
	
	fileprivate weak var embeddingView: UIView?
	fileprivate var videoCompletion: ((_ videoURL: URL?, _ error: NSError?) -> Void)?
	
	fileprivate var sessionQueue: DispatchQueue = DispatchQueue(label: "CameraSessionQueue", attributes: [])
	
	fileprivate lazy var frontCameraDevice: AVCaptureDevice? = {
		let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! [AVCaptureDevice]
		return devices.filter{$0.position == .front}.first
	}()
	
	fileprivate lazy var backCameraDevice: AVCaptureDevice? = {
		let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! [AVCaptureDevice]
		return devices.filter{$0.position == .back}.first
	}()
	
	fileprivate lazy var mic: AVCaptureDevice? = {
		return AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
	}()
	
	fileprivate var stillImageOutput: AVCaptureStillImageOutput?
	fileprivate var movieOutput: AVCaptureMovieFileOutput?
	fileprivate var library: PHPhotoLibrary?
	
	fileprivate var cameraIsSetup = false
	fileprivate var cameraIsObservingDeviceOrientation = false
	
	fileprivate var zoomScale       = CGFloat(1.0)
	fileprivate var beginZoomScale  = CGFloat(1.0)
	fileprivate var maxZoomScale    = CGFloat(1.0)
	
	fileprivate var focusRing: UIView?
	
	fileprivate var tempFilePath: URL = {
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
	open func addPreviewLayerToView(_ view: UIView) -> CameraState {
		return addPreviewLayerToView(view, newCameraOutputMode: cameraOutputMode)
	}
	open func addPreviewLayerToView(_ view: UIView, newCameraOutputMode: CameraOutputMode) -> CameraState {
		return addLayerPreviewToView(view, newCameraOutputMode: newCameraOutputMode, completion: nil)
	}
	
	open func addLayerPreviewToView(_ view: UIView, newCameraOutputMode: CameraOutputMode, completion: ((Void) -> Void)?) -> CameraState {
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
				_setupCamera({ Void -> Void in
					self._addPreviewLayerToView(view)
					self.cameraOutputMode = newCameraOutputMode
					if let validCompletion = completion {
						validCompletion()
					}
				})
			}
		}
		return _checkIfCameraIsAvailable()
	}
	
	/**
	Asks the user for camera permissions. Only works if the permissions are not yet determined. Note that it'll also automaticaly ask about the microphone permissions if you selected VideoWithMic output.
	
	:param: completion Completion block with the result of permission request
	*/
	open func askUserForCameraPermission(_ completion: @escaping (Bool) -> Void) {
		AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (alowedAccess) -> Void in
			if self.cameraOutputMode == .videoWithMic {
				AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeAudio, completionHandler: { (alowedAccess) -> Void in
					DispatchQueue.main.sync(execute: { () -> Void in
						completion(alowedAccess)
					})
				})
			} else {
				DispatchQueue.main.sync(execute: { () -> Void in
					completion(alowedAccess)
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
				_setupCamera({Void -> Void in
					if let validEmbeddingView = self.embeddingView {
						self._addPreviewLayerToView(validEmbeddingView)
					}
					self._startFollowingDeviceOrientation()
				})
			}
		}
	}
	
	/**
	Stops running capture session and removes all setup devices, inputs and outputs.
	*/
	open func stopAndRemoveCaptureSession() {
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
	
	/**
	Captures still image from currently running capture session.
	
	:param: imageCompletion Completion block containing the captured UIImage
	*/
	open func capturePictureWithCompletion(_ imageCompletion: @escaping (UIImage?, NSError?) -> Void) {
		self.capturePictureDataWithCompletion { data, error in
			
			guard error == nil, let imageData = data else {
				imageCompletion(nil, error)
				return
			}
			
			if self.writeFilesToPhoneLibrary == true, let library = self.library  {
				
				
				library.performChanges({
					PHAssetChangeRequest.creationRequestForAsset(from: UIImage(data: imageData)!)
				}, completionHandler: { success, error in
					guard error != nil else {
						return
					}
					
					DispatchQueue.main.async(execute: {
						self._show(NSLocalizedString("Error", comment:""), message: (error?.localizedDescription)!)
					})
				})
			}
			imageCompletion(UIImage(data: imageData), nil)
		}
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
			self._getStillImageOutput().captureStillImageAsynchronously(from: self._getStillImageOutput().connection(withMediaType: AVMediaTypeVideo), completionHandler: { [unowned self] sample, error in
				
				
				guard error == nil else {
					DispatchQueue.main.async(execute: {
						self._show(NSLocalizedString("Error", comment:""), message: (error?.localizedDescription)!)
					})
					imageCompletion(nil, error as NSError?)
					return
				}
				
				let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sample)
				
				
				imageCompletion(imageData, nil)
				
			})
		})
		
	}
	
	/**
	Starts recording a video with or without voice as in the session preset.
	*/
	open func startRecordingVideo() {
		if cameraOutputMode != .stillImage {
			_getMovieOutput().startRecording(toOutputFileURL: tempFilePath, recordingDelegate: self)
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
		flashMode = CameraFlashMode(rawValue: (flashMode.rawValue+1)%3)!
		return flashMode
	}
	
	/**
	Change current output quality mode to next value from available ones.
	
	:returns: Current quality mode: Low / Medium / High
	*/
	open func changeQualityMode() -> CameraOutputQuality {
		cameraOutputQuality = CameraOutputQuality(rawValue: (cameraOutputQuality.rawValue+1)%3)!
		return cameraOutputQuality
	}
	
	// MARK: - AVCaptureFileOutputRecordingDelegate
	
	open func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
		captureSession?.beginConfiguration()
		if flashMode != .off {
			_updateTorch(flashMode)
		}
		captureSession?.commitConfiguration()
	}
	
	open func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
		_updateTorch(.off)
		if (error != nil) {
			_show(NSLocalizedString("Unable to save video to the iPhone", comment:""), message: error.localizedDescription)
		} else {
			
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
				
				PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
			}, completionHandler: { success, error in
				if (error != nil) {
					self._show(NSLocalizedString("Unable to save video to the iPhone.", comment:""), message: error!.localizedDescription)
					self._executeVideoCompletionWithURL(nil, error: error as NSError?)
				} else {
					self._executeVideoCompletionWithURL(fileURL, error: error as NSError?)
				}
			})
		}
	}
	
	// MARK: - UIGestureRecognizerDelegate - focus
	
	fileprivate func attachFocus(_ view: UIView) {
		let tap = UITapGestureRecognizer(target: self, action: #selector(CameraManager._focusStart(_:)))
		view.addGestureRecognizer(tap)
		tap.delegate = self
		
		focusRing = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
		focusRing?.backgroundColor = UIColor(white: 1.0, alpha: 0.3)
		focusRing?.translatesAutoresizingMaskIntoConstraints = false
		focusRing?.layer.masksToBounds = true
		focusRing?.layer.cornerRadius = 15
		focusRing?.layer.borderColor = UIColor.white.cgColor
		focusRing?.layer.borderWidth = 2
		focusRing?.layer.zPosition = 10
		focusRing?.alpha = 0
		
		DispatchQueue.main.sync {
			view.addSubview(focusRing!)
		}
	}
	
	@objc
	fileprivate func _focusStart(_ recognizer: UITapGestureRecognizer) {
		guard let view = embeddingView,
			let previewLayer = previewLayer
			else { return }
		
		let numTouch = recognizer.numberOfTouches
		
		if numTouch > 0 {
			let location = recognizer.location(ofTouch: 0, in: view)
			let convertedTouch = previewLayer.convert(location, from: previewLayer.superlayer)
			let relativeTouch = CGPoint(x: convertedTouch.x / previewLayer.frame.size.width, y: convertedTouch.y / previewLayer.frame.size.height)
			
			_setFocusRing(location)
			_focus(relativeTouch)
		}
	}
	
	fileprivate func _setFocusRing(_ location: CGPoint) {
		if focusRing != nil {
			focusRing?.frame.origin.x = location.x - (focusRing!.frame.size.width / 2)
			focusRing?.frame.origin.y = location.y - (focusRing!.frame.size.height / 2)
			
			_animateFocusRing()
		}
	}
	
	fileprivate func _animateFocusRing() {
		UIView.animate(withDuration: 0.2, animations: {
			self.focusRing?.alpha = 1.0
		}, completion: { (complete) in
			
			UIView.animateKeyframes(withDuration: 3.0, delay: 0.0, options: [], animations: {
				UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.25) {
					self.focusRing?.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
				}
				
				UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.25) {
					self.focusRing?.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
				}
				
				UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.25) {
					self.focusRing?.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
				}
				
				UIView.addKeyframe(withRelativeStartTime: 0.75, relativeDuration: 0.25) {
					self.focusRing?.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
				}
			}, completion: { (done) in
				UIView.animate(withDuration: 0.7, animations: {
					self.focusRing?.alpha = 0.0
				})
			})
		})
	}
	
	fileprivate func _focus(_ point: CGPoint) {
		
		do {
			let captureDevice = AVCaptureDevice.devices().first as? AVCaptureDevice
			try captureDevice?.lockForConfiguration()
			
			captureDevice?.focusMode = .autoFocus
			captureDevice?.focusPointOfInterest = point
			
			captureDevice?.unlockForConfiguration()
			
		} catch {
			print("Error locking configuration")
		}
	}
	
	// MARK: - UIGestureRecognizerDelegate - zoom
	
	fileprivate func attachZoom(_ view: UIView) {
		let pinch = UIPinchGestureRecognizer(target: self, action: #selector(CameraManager._zoomStart(_:)))
		view.addGestureRecognizer(pinch)
		pinch.delegate = self
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
		do {
			let captureDevice = AVCaptureDevice.devices().first as? AVCaptureDevice
			try captureDevice?.lockForConfiguration()
			
			zoomScale = max(1.0, min(beginZoomScale * scale, maxZoomScale))
			
			captureDevice?.videoZoomFactor = zoomScale
			
			captureDevice?.unlockForConfiguration()
			
		} catch {
			print("Error locking configuration")
		}
	}
	
	// MARK: - CameraManager()
	
	fileprivate func _updateTorch(_ flashMode: CameraFlashMode) {
		captureSession?.beginConfiguration()
		let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
		for  device in devices!  {
			let captureDevice = device as! AVCaptureDevice
			if (captureDevice.position == AVCaptureDevicePosition.back) {
				let avTorchMode = AVCaptureTorchMode(rawValue: flashMode.rawValue)
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
	
	
	fileprivate func _executeVideoCompletionWithURL(_ url: URL?, error: NSError?) {
		if let validCompletion = videoCompletion {
			validCompletion(url, error)
			videoCompletion = nil
		}
	}
	
	fileprivate func _getMovieOutput() -> AVCaptureMovieFileOutput {
		var shouldReinitializeMovieOutput = movieOutput == nil
		if !shouldReinitializeMovieOutput {
			if let connection = movieOutput!.connection(withMediaType: AVMediaTypeVideo) {
				shouldReinitializeMovieOutput = shouldReinitializeMovieOutput || !connection.isActive
			}
		}
		
		if shouldReinitializeMovieOutput {
			movieOutput = AVCaptureMovieFileOutput()
			movieOutput!.movieFragmentInterval = kCMTimeInvalid
			
			if let captureSession = captureSession {
				if captureSession.canAddOutput(movieOutput) {
					captureSession.beginConfiguration()
					captureSession.addOutput(movieOutput)
					captureSession.commitConfiguration()
				}
			}
		}
		return movieOutput!
	}
	
	fileprivate func _getStillImageOutput() -> AVCaptureStillImageOutput {
		var shouldReinitializeStillImageOutput = stillImageOutput == nil
		if !shouldReinitializeStillImageOutput {
			if let connection = stillImageOutput!.connection(withMediaType: AVMediaTypeVideo) {
				shouldReinitializeStillImageOutput = shouldReinitializeStillImageOutput || !connection.isActive
			}
		}
		if shouldReinitializeStillImageOutput {
			stillImageOutput = AVCaptureStillImageOutput()
			
			if let captureSession = captureSession {
				if captureSession.canAddOutput(stillImageOutput) {
					captureSession.beginConfiguration()
					captureSession.addOutput(stillImageOutput)
					captureSession.commitConfiguration()
				}
			}
		}
		return stillImageOutput!
	}
	
	@objc fileprivate func _orientationChanged() {
		var currentConnection: AVCaptureConnection?;
		switch cameraOutputMode {
		case .stillImage:
			currentConnection = stillImageOutput?.connection(withMediaType: AVMediaTypeVideo)
		case .videoOnly, .videoWithMic:
			currentConnection = _getMovieOutput().connection(withMediaType: AVMediaTypeVideo)
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
			DispatchQueue.main.async(execute: { () -> Void in
				if let validEmbeddingView = self.embeddingView {
					validPreviewLayer.frame = validEmbeddingView.bounds
				}
			})
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
	
	fileprivate func _setupCamera(_ completion: @escaping (Void) -> Void) {
		captureSession = AVCaptureSession()
		
		sessionQueue.async(execute: {
			if let validCaptureSession = self.captureSession {
				validCaptureSession.beginConfiguration()
				validCaptureSession.sessionPreset = AVCaptureSessionPresetHigh
				self._updateCameraDevice(self.cameraDevice)
				self._setupOutputs()
				self._setupOutputMode(self.cameraOutputMode, oldCameraOutputMode: nil)
				self._setupPreviewLayer()
				validCaptureSession.commitConfiguration()
				self._updateFlasMode(self.flashMode)
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
			guard let _ = self.previewLayer else {
				return
			}
			self.previewLayer!.frame = view.layer.bounds
			view.clipsToBounds = true
			view.layer.addSublayer(self.previewLayer!)
		})
	}
	
	fileprivate func _setupMaxZoomScale() {
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
	
	fileprivate func _checkIfCameraIsAvailable() -> CameraState {
		let deviceHasCamera = UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.rear) || UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.front)
		if deviceHasCamera {
			let authorizationStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
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
			captureSession?.addOutput(_getMovieOutput())
			
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
			movieOutput!.movieFragmentInterval = kCMTimeInvalid
		}
		if library == nil {
			library = PHPhotoLibrary.shared()
		}
	}
	
	fileprivate func _setupPreviewLayer() {
		if let validCaptureSession = captureSession {
			previewLayer = AVCaptureVideoPreviewLayer(session: validCaptureSession)
			previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
		}
	}
	
	fileprivate func _updateCameraDevice(_ deviceType: CameraDevice) {
		if let validCaptureSession = captureSession {
			validCaptureSession.beginConfiguration()
			let inputs = validCaptureSession.inputs as! [AVCaptureInput]
			
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
			validCaptureSession.commitConfiguration()
		}
	}
	
	fileprivate func _updateFlasMode(_ flashMode: CameraFlashMode) {
		captureSession?.beginConfiguration()
		let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
		for  device in devices!  {
			let captureDevice = device as! AVCaptureDevice
			if (captureDevice.position == AVCaptureDevicePosition.back) {
				let avFlashMode = AVCaptureFlashMode(rawValue: flashMode.rawValue)
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
	
	fileprivate func _updateCameraQualityMode(_ newCameraOutputQuality: CameraOutputQuality) {
		if let validCaptureSession = captureSession {
			var sessionPreset = AVCaptureSessionPresetLow
			switch (newCameraOutputQuality) {
			case CameraOutputQuality.low:
				sessionPreset = AVCaptureSessionPresetLow
			case CameraOutputQuality.medium:
				sessionPreset = AVCaptureSessionPresetMedium
			case CameraOutputQuality.high:
				if cameraOutputMode == .stillImage {
					sessionPreset = AVCaptureSessionPresetPhoto
				} else {
					sessionPreset = AVCaptureSessionPresetHigh
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
		guard let inputs = captureSession?.inputs as? [AVCaptureInput] else { return }
		
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
