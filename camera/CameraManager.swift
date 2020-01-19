//
//  CameraManager.swift
//  camera
//
//  Created by Natalia Terlecka on 10/10/14.
//  Copyright (c) 2014 Imaginary Cloud. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import PhotosUI
import ImageIO
import MobileCoreServices
import CoreLocation
import CoreMotion
import CoreImage

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

public enum CaptureResult {
    case success(content: CaptureContent)
    case failure(Error)

    init(_ image: UIImage) {
        self = .success(content: .image(image))
    }

    init(_ data: Data) {
        self = .success(content: .imageData(data))
    }

    init(_ asset: PHAsset) {
        self = .success(content: .asset(asset))
    }

    var imageData: Data? {
        if case let .success(content) = self {
            return content.asData
        } else {

            return nil
        }
    }
}

public enum CaptureContent {
    case imageData(Data)
    case image(UIImage)
    case asset(PHAsset)
}

extension CaptureContent {

    public var asImage: UIImage? {

        switch self {
        case let .image(image): return image
        case let .imageData(data): return UIImage(data: data)
        case let .asset(asset):
            if let data = getImageData(fromAsset: asset) {
                return UIImage(data: data)
            } else {
                return nil
            }
        }
    }

    public var asData: Data? {

        switch self {
        case let .image(image): return image.jpegData(compressionQuality: 0.8)
        case let .imageData(data): return data
        case let .asset(asset): return getImageData(fromAsset: asset)
        }

    }

    private func getImageData(fromAsset asset: PHAsset) -> Data? {

        var imageData: Data? = nil
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.version = .original
        options.isSynchronous = true
        manager.requestImageData(for: asset, options: options) { data, _, _, _ in

            imageData = data
        }
        return imageData
    }
}

public enum CaptureError: Error {

    case noImageData
    case invalidImageData
    case noVideoConnection
    case noSampleBuffer
    case assetNotSaved
}

/// Class for handling iDevices custom camera usage
open class CameraManager: NSObject, AVCaptureFileOutputRecordingDelegate, UIGestureRecognizerDelegate {
    
    // MARK: - Public properties
    
    // Property for custom image album name.
    open var imageAlbumName: String?
    
    // Property for custom image album name.
    open var videoAlbumName: String?
    
    /// Property for capture session to customize camera settings.
    open var captureSession: AVCaptureSession?
    
    /**
     Property to determine if the manager should show the error for the user. If you want to show the errors yourself set this to false. If you want to add custom error UI set showErrorBlock property.
     - note: Default value is **false**
     */
    open var showErrorsToUsers = false
    
    /// Property to determine if the manager should show the camera permission popup immediatly when it's needed or you want to show it manually. Default value is true. Be carful cause using the camera requires permission, if you set this value to false and don't ask manually you won't be able to use the camera.
    open var showAccessPermissionPopupAutomatically = true
    
    /// A block creating UI to present error message to the user. This can be customised to be presented on the Window root view controller, or to pass in the viewController which will present the UIAlertController, for example.
    open var showErrorBlock:(_ erTitle: String, _ erMessage: String) -> Void = { (erTitle: String, erMessage: String) -> Void in
        
        var alertController = UIAlertController(title: erTitle, message: erMessage, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { (alertAction) -> Void in  }))
        
        if let topController = UIApplication.shared.keyWindow?.rootViewController {
            topController.present(alertController, animated: true, completion:nil)
        }
    }
    
    /**
     Property to determine if manager should write the resources to the phone library.
     - note: Default value is **true**
     */
    open var writeFilesToPhoneLibrary = true
    
    /**
     Property to determine if manager should follow device orientation.
     - note: Default value is **true**
     */
    open var shouldRespondToOrientationChanges = true {
        didSet {
            if shouldRespondToOrientationChanges {
                _startFollowingDeviceOrientation()
            } else {
                _stopFollowingDeviceOrientation()
            }
        }
    }
    
    /**
     Property to determine if manager should horizontally flip image took by front camera.
     - note: Default value is **false**
     */
    open var shouldFlipFrontCameraImage = false
    
    /**
     Property to determine if manager should keep view with the same bounds when the orientation changes.
     - note: Default value is **false**
     */
    open var shouldKeepViewAtOrientationChanges = false
    
    /**
     Property to determine if manager should enable tap to focus on camera preview.
     - note: Default value is **true**
     */
    open var shouldEnableTapToFocus = true {
        didSet {
            focusGesture.isEnabled = shouldEnableTapToFocus
        }
    }
    
    /**
     Property to determine if manager should enable pinch to zoom on camera preview.
     - note: Default value is **true**
     */
    open var shouldEnablePinchToZoom = true {
        didSet {
            zoomGesture.isEnabled = shouldEnablePinchToZoom
        }
    }
    
    /**
     Property to determine if manager should enable pan to change exposure/brightness.
     - note: Default value is **true**
     */
    open var shouldEnableExposure = true {
        didSet {
            exposureGesture.isEnabled = shouldEnableExposure
        }
    }
    
    /// Property to determine if the camera is ready to use.
    open var cameraIsReady: Bool {
        get {
            return cameraIsSetup
        }
    }
    
    /// Property to determine if current device has front camera.
    open var hasFrontCamera: Bool = {
        let frontDevices = AVCaptureDevice.videoDevices.filter { $0.position == .front }
        return !frontDevices.isEmpty
    }()
    
    /// Property to determine if current device has flash.
    open var hasFlash: Bool = {
        let hasFlashDevices = AVCaptureDevice.videoDevices.filter { $0.hasFlash }
        return !hasFlashDevices.isEmpty
    }()
    
    /**
     Property to enable or disable flip animation when switch between back and front camera.
     - note: Default value is **true**
     */
    open var animateCameraDeviceChange: Bool = true
    
    /**
     Property to enable or disable shutter animation when taking a picture.
     - note: Default value is **true**
     */
    open var animateShutter: Bool = true
    
    /**
     Property to enable or disable location services. Location services in camera is used for EXIF data.
     - note: Default value is **false**
     */
    open var shouldUseLocationServices: Bool = false {
        didSet {
            if shouldUseLocationServices {
                self.locationManager = CameraLocationManager()
            }
        }
    }
    
    /// Property to change camera device between front and back.
    open var cameraDevice = CameraDevice.back {
        didSet {
            if cameraIsSetup && cameraDevice != oldValue {
                if animateCameraDeviceChange {
                    _doFlipAnimation()
                }
                _updateCameraDevice(cameraDevice)
                _updateIlluminationMode(flashMode)
                _setupMaxZoomScale()
                _zoom(0)
                _orientationChanged()
            }
        }
    }
    
    /// Property to change camera flash mode.
    open var flashMode = CameraFlashMode.off {
        didSet {
            if cameraIsSetup && flashMode != oldValue {
                _updateIlluminationMode(flashMode)
            }
        }
    }
    
    /// Property to change camera output quality.
    open var cameraOutputQuality = CameraOutputQuality.high {
        didSet {
            if cameraIsSetup && cameraOutputQuality != oldValue {
                _updateCameraQualityMode(cameraOutputQuality)
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
    
    /// Property to check video recording duration when in progress.
    open var recordedDuration : CMTime { return movieOutput?.recordedDuration ?? CMTime.zero }
    
    /// Property to check video recording file size when in progress.
    open var recordedFileSize : Int64 { return movieOutput?.recordedFileSize ?? 0 }
    
    /// Property to set focus mode when tap to focus is used (_focusStart).
    open var focusMode : AVCaptureDevice.FocusMode = .continuousAutoFocus
    
    /// Property to set exposure mode when tap to focus is used (_focusStart).
    open var exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure
    
    /// Property to set video stabilisation mode during a video record session
    open var videoStabilisationMode : AVCaptureVideoStabilizationMode = .auto
    
    
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
    
    fileprivate var coreMotionManager: CMMotionManager!
    
    /// Real device orientation from accelerometer
    fileprivate var deviceOrientation: UIDeviceOrientation = .portrait
    
    // MARK: - CameraManager
    
    /**
     Inits a capture session and adds a preview layer to the given view. Preview layer bounds will automaticaly be set to match given view. Default session is initialized with still image output.
     
     :param: view The view you want to add the preview layer to
     :param: cameraOutputMode The mode you want capturesession to run image / video / video and microphone
     :param: completion Optional completion block
     
     :returns: Current state of the camera: Ready / AccessDenied / NoDeviceFound / NotDetermined.
     */
    @discardableResult open func addPreviewLayerToView(_ view: UIView) -> CameraState {
        return addPreviewLayerToView(view, newCameraOutputMode: cameraOutputMode)
    }
  
    @discardableResult open func addPreviewLayerToView(_ view: UIView, newCameraOutputMode: CameraOutputMode) -> CameraState {
        return addLayerPreviewToView(view, newCameraOutputMode: newCameraOutputMode, completion: nil)
    }
    
    @discardableResult open func addLayerPreviewToView(_ view: UIView, newCameraOutputMode: CameraOutputMode, completion: (() -> Void)?) -> CameraState {
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
     Zoom in to the requested scale.
    */
    open func zoom(_ scale: CGFloat) {
        _zoom(scale)
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
                self.sessionQueue.async(execute: {
                    validCaptureSession.startRunning()
                    self._startFollowingDeviceOrientation()
                })
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
        self.stopCaptureSession()
        let oldAnimationValue = self.animateCameraDeviceChange
        self.animateCameraDeviceChange = false
        self.cameraDevice = .back
        self.cameraIsSetup = false
        self.previewLayer = nil
        self.captureSession = nil
        self.frontCameraDevice = nil
        self.backCameraDevice = nil
        self.mic = nil
        self.stillImageOutput = nil
        self.movieOutput = nil
        self.animateCameraDeviceChange = oldAnimationValue
    }

    /**
     Captures still image from currently running capture session.

     :param: imageCompletion Completion block containing the captured UIImage
     */
    @available(*, deprecated)
    open func capturePictureWithCompletion(_ imageCompletion: @escaping (UIImage?, NSError?) -> Void) {

        func completion(_ result: CaptureResult) {

            switch result {

            case let .success(content):
                imageCompletion(content.asImage, nil)
            case .failure:
                imageCompletion(nil, NSError())
            }
        }

        capturePictureWithCompletion(completion)
    }

    /**
     Captures still image from currently running capture session.
     
     :param: imageCompletion Completion block containing the captured UIImage
     */
    open func capturePictureWithCompletion(_ imageCompletion: @escaping (CaptureResult) -> Void) {
        self.capturePictureDataWithCompletion { result in

            guard let imageData = result.imageData else {

                if case let .failure(error) = result {
                    imageCompletion(.failure(error))
                } else {
                    imageCompletion(.failure(CaptureError.noImageData))
                }

                return
            }
            
            if self.animateShutter {
                self._performShutterAnimation {
                    self._capturePicture(imageData, imageCompletion)
                }
            } else {
                self._capturePicture(imageData, imageCompletion)
            }
        }
    }
    
    fileprivate func _capturePicture(_ imageData: Data, _ imageCompletion: @escaping (CaptureResult) -> Void) {
        guard let img = UIImage(data: imageData) else {
            imageCompletion(.failure(NSError()))
            return
        }
        
        let image = fixOrientation(withImage: img)
        
        if writeFilesToPhoneLibrary {
            
            let filePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempImg\(Int(Date().timeIntervalSince1970)).jpg")
            let newImageData = _imageDataWithEXIF(forImage: image, imageData) as Data
                
            do {
                
                try newImageData.write(to: filePath)
                
                // make sure that doesn't fail the first time
                if PHPhotoLibrary.authorizationStatus() != .authorized {
                    PHPhotoLibrary.requestAuthorization { (status) in
                        if status == PHAuthorizationStatus.authorized {
                            self._saveImageToLibrary(atFileURL: filePath, imageCompletion)
                        }
                    }
                } else {
                    self._saveImageToLibrary(atFileURL: filePath, imageCompletion)
                }

            } catch {
                imageCompletion(.failure(error))
                return
            }
        }
        
        imageCompletion(CaptureResult(image))
    }
    
    fileprivate func _setVideoWithGPS(forLocation location: CLLocation) {
        let metadata = AVMutableMetadataItem()
        metadata.keySpace = AVMetadataKeySpace.quickTimeMetadata
        metadata.key = AVMetadataKey.quickTimeMetadataKeyLocationISO6709 as NSString
        metadata.identifier = AVMetadataIdentifier.quickTimeMetadataLocationISO6709
        metadata.value = String(format: "%+09.5f%+010.5f%+.0fCRSWGS_84", location.coordinate.latitude, location.coordinate.longitude, location.altitude) as NSString
        _getMovieOutput().metadata = [metadata]
    }
    
    fileprivate func _imageDataWithEXIF(forImage image: UIImage, _ imageData: Data) -> CFMutableData {
        // get EXIF info
        let cgImage = image.cgImage
        let newImageData:CFMutableData = CFDataCreateMutable(nil, 0)
        let type = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, "image/jpg" as CFString, kUTTypeImage)
        let destination:CGImageDestination = CGImageDestinationCreateWithData(newImageData, (type?.takeRetainedValue())!, 1, nil)!
    
        let imageSourceRef = CGImageSourceCreateWithData(imageData as CFData, nil)
        let currentProperties = CGImageSourceCopyPropertiesAtIndex(imageSourceRef!, 0, nil)
        let mutableDict = NSMutableDictionary(dictionary: currentProperties!)
        
        if let location = self.locationManager?.latestLocation {
            mutableDict.setValue(_gpsMetadata(withLocation: location), forKey: kCGImagePropertyGPSDictionary as String)
        }
    
        CGImageDestinationAddImage(destination, cgImage!, mutableDict as CFDictionary)
        CGImageDestinationFinalize(destination)
    
        return newImageData
    }
    
    fileprivate func _gpsMetadata(withLocation location: CLLocation) -> NSMutableDictionary {
        let f = DateFormatter()
        f.timeZone = TimeZone(abbreviation: "UTC")
        
        f.dateFormat = "yyyy:MM:dd"
        let isoDate = f.string(from: location.timestamp)

        f.dateFormat = "HH:mm:ss.SSSSSS"
        let isoTime = f.string(from: location.timestamp)
    
        let GPSMetadata = NSMutableDictionary()
        let altitudeRef = Int(location.altitude < 0.0 ? 1 : 0)
        let latitudeRef = location.coordinate.latitude < 0.0 ? "S" : "N"
        let longitudeRef = location.coordinate.longitude < 0.0 ? "W" : "E"
        
        // GPS metadata
        GPSMetadata[(kCGImagePropertyGPSLatitude as String)] = abs(location.coordinate.latitude)
        GPSMetadata[(kCGImagePropertyGPSLongitude as String)] = abs(location.coordinate.longitude)
        GPSMetadata[(kCGImagePropertyGPSLatitudeRef as String)] = latitudeRef
        GPSMetadata[(kCGImagePropertyGPSLongitudeRef as String)] = longitudeRef
        GPSMetadata[(kCGImagePropertyGPSAltitude as String)] = Int(abs(location.altitude))
        GPSMetadata[(kCGImagePropertyGPSAltitudeRef as String)] = altitudeRef
        GPSMetadata[(kCGImagePropertyGPSTimeStamp as String)] = isoTime
        GPSMetadata[(kCGImagePropertyGPSDateStamp as String)] = isoDate
        
        return GPSMetadata
    }
    
    fileprivate func _saveImageToLibrary(atFileURL filePath: URL, _ imageCompletion: @escaping (CaptureResult) -> Void) {
        
        let location = self.locationManager?.latestLocation
        let date = Date()

        library?.save(imageAtURL: filePath, albumName: self.imageAlbumName, date: date, location: location) { asset in

            if let asset = asset {
                imageCompletion(CaptureResult(asset))
            } else {
                imageCompletion(.failure(CaptureError.assetNotSaved))
            }
        }
    }
    
    /**
     Captures still image from currently running capture session.
     
     :param: imageCompletion Completion block containing the captured imageData
     */
    @available(*, deprecated)
    open func capturePictureDataWithCompletion(_ imageCompletion: @escaping (Data?, NSError?) -> Void) {

        func completion(_ result: CaptureResult) {

            switch result {

            case let .success(content):
                imageCompletion(content.asData, nil)
            case .failure:
                imageCompletion(nil, NSError())
            }
        }
        capturePictureDataWithCompletion(completion)
    }

    /**
     Captures still image from currently running capture session.

     :param: imageCompletion Completion block containing the captured imageData
     */
    open func capturePictureDataWithCompletion(_ imageCompletion: @escaping (CaptureResult) -> Void) {
        guard cameraIsSetup else {
            _show(NSLocalizedString("No capture session setup", comment:""), message: NSLocalizedString("I can't take any picture", comment:""))
            return
        }
        
        guard cameraOutputMode == .stillImage else {
            _show(NSLocalizedString("Capture session output mode video", comment:""), message: NSLocalizedString("I can't take any picture", comment:""))
            return
        }
        
        _updateIlluminationMode(flashMode)
        
        sessionQueue.async(execute: {
            let stillImageOutput = self._getStillImageOutput()
            if let connection = stillImageOutput.connection(with: AVMediaType.video),
                connection.isEnabled {
                if self.cameraDevice == CameraDevice.front && connection.isVideoMirroringSupported &&
                    self.shouldFlipFrontCameraImage {
                    connection.isVideoMirrored = true
                }
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = self._currentCaptureVideoOrientation()
                }
                
                stillImageOutput.captureStillImageAsynchronously(from: connection, completionHandler: { [weak self] sample, error in
                    
                    if let error = error {
                        DispatchQueue.main.async(execute: {
                            self?._show(NSLocalizedString("Error", comment:""), message: error.localizedDescription)
                        })
                        imageCompletion(.failure(error))
                        return
                    }
                    
                    guard let sample = sample else { imageCompletion(.failure(CaptureError.noSampleBuffer)); return }
                    if let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sample) {
                        imageCompletion(CaptureResult(imageData))
                    } else {
                        imageCompletion(.failure(CaptureError.noImageData))
                    }
                    
                })
            } else {
                imageCompletion(.failure(CaptureError.noVideoConnection))
            }
        })
    }

    fileprivate func _imageOrientation(forDeviceOrientation deviceOrientation: UIDeviceOrientation, isMirrored: Bool) -> UIImage.Orientation {
        
        switch deviceOrientation {
        case .landscapeLeft:
            return isMirrored ? .upMirrored : .up
        case .landscapeRight:
            return isMirrored ? .downMirrored : .down
        default:
            break
        }

        return isMirrored ? .leftMirrored : .right
    }
    
    /**
     Starts recording a video with or without voice as in the session preset.
     */
    open func startRecordingVideo() {
        if cameraOutputMode != .stillImage {
            let videoOutput = _getMovieOutput()
            // setup video mirroring
            for connection in videoOutput.connections {
                for port in connection.inputPorts {
                    
                    if port.mediaType == AVMediaType.video {
                        let videoConnection = connection as AVCaptureConnection
                        if videoConnection.isVideoMirroringSupported {
                            videoConnection.isVideoMirrored = (cameraDevice == CameraDevice.front && shouldFlipFrontCameraImage)
                        }
                        
                        if videoConnection.isVideoStabilizationSupported {
                            videoConnection.preferredVideoStabilizationMode = self.videoStabilisationMode
                        }
                    }
                }
            }
            
            let specs = [kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String: AVMetadataIdentifier.quickTimeMetadataLocationISO6709,
                         kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String: kCMMetadataDataType_QuickTimeMetadataLocation_ISO6709 as String] as [String : Any]
            
            var locationMetadataDesc: CMFormatDescription?
            CMMetadataFormatDescriptionCreateWithMetadataSpecifications(allocator: kCFAllocatorDefault, metadataType: kCMMetadataFormatType_Boxed, metadataSpecifications: [specs] as CFArray, formatDescriptionOut: &locationMetadataDesc)
            
            // Create the metadata input and add it to the session.
            guard let captureSession = captureSession, let locationMetadata = locationMetadataDesc else {
                    return
            }

            let newLocationMetadataInput = AVCaptureMetadataInput(formatDescription: locationMetadata, clock: CMClockGetHostTimeClock())
            captureSession.addInputWithNoConnections(newLocationMetadataInput)
            
            // Connect the location metadata input to the movie file output.
            let inputPort = newLocationMetadataInput.ports[0]
            captureSession.addConnection(AVCaptureConnection(inputPorts: [inputPort], output: videoOutput))
            
            _updateIlluminationMode(flashMode)
            
            videoOutput.startRecording(to: _tempFilePath(), recordingDelegate: self)
        } else {
            _show(NSLocalizedString("Capture session output still image", comment:""), message: NSLocalizedString("I can only take pictures", comment:""))
        }
    }
    
    /**
     Stop recording a video. Save it to the cameraRoll and give back the url.
     */
    open func stopVideoRecording(_ completion:((_ videoURL: URL?, _ error: NSError?) -> Void)?) {
        if let runningMovieOutput = movieOutput,
            runningMovieOutput.isRecording {
                videoCompletion = completion
                runningMovieOutput.stopRecording()
        }
    }
    
    /**
     Check if the device rotation is locked
     */
    open func deviceOrientationMatchesInterfaceOrientation() -> Bool {
        return deviceOrientation == UIDevice.current.orientation
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
    
    /**
     Check the camera device has flash
     */
    open func hasFlash(for cameraDevice: CameraDevice) -> Bool {
        let devices = AVCaptureDevice.videoDevices
        for device in devices {
            if device.position == .back && cameraDevice == .back {
                return device.hasFlash
            } else if device.position == .front && cameraDevice == .front {
                return device.hasFlash
            }
        }
        return false
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate
    public func fileOutput(captureOutput: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        captureSession?.beginConfiguration()
        if flashMode != .off {
            _updateIlluminationMode(flashMode)
        }
        
        captureSession?.commitConfiguration()
    }
    
    open func fileOutput(_ captureOutput: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            _show(NSLocalizedString("Unable to save video to the device", comment:""), message: error.localizedDescription)
        } else {
            if writeFilesToPhoneLibrary {
                if PHPhotoLibrary.authorizationStatus() == .authorized {
                    _saveVideoToLibrary(outputFileURL)
                } else {
                    PHPhotoLibrary.requestAuthorization({ (autorizationStatus) in
                        if autorizationStatus == .authorized {
                            self._saveVideoToLibrary(outputFileURL)
                        }
                    })
                }
            } else {
                _executeVideoCompletionWithURL(outputFileURL, error: error as NSError?)
            }
        }
    }
    
    fileprivate func _saveVideoToLibrary(_ fileURL: URL) {
        
        let location = self.locationManager?.latestLocation
        let date = Date()
        
        library?.save(videoAtURL: fileURL, albumName: self.videoAlbumName, date: date, location: location, completion: { _ in
            self._executeVideoCompletionWithURL(fileURL, error: nil)
        })

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
            beginZoomScale = zoomScale
        }
        
        return true
    }
    
    @objc fileprivate func _zoomStart(_ recognizer: UIPinchGestureRecognizer) {
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
            self.focusGesture.addTarget(self, action: #selector(CameraManager._focusStart(_:)))
            view.addGestureRecognizer(self.focusGesture)
            self.focusGesture.delegate = self
        }
    }
    
    fileprivate lazy var exposureGesture = UIPanGestureRecognizer()
    
    fileprivate func attachExposure(_ view: UIView) {
        DispatchQueue.main.async {
            self.exposureGesture.addTarget(self, action: #selector(CameraManager._exposureStart(_:)))
            view.addGestureRecognizer(self.exposureGesture)
            self.exposureGesture.delegate = self
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
        
        _changeExposureMode(mode: .continuousAutoExposure)
        translationY = 0
        exposureValue = 0.5
        
        if let validDevice = device,
            let validPreviewLayer = previewLayer,
            let view = recognizer.view
        {
                let pointInPreviewLayer = view.layer.convert(recognizer.location(in: view), to: validPreviewLayer)
                let pointOfInterest = validPreviewLayer.captureDevicePointConverted(fromLayerPoint: pointInPreviewLayer)
                
                do {
                    try validDevice.lockForConfiguration()
                    
                    _showFocusRectangleAtPoint(pointInPreviewLayer, inLayer: validPreviewLayer)
                    
                    if validDevice.isFocusPointOfInterestSupported {
                        validDevice.focusPointOfInterest = pointOfInterest
                    }
                    
                    if  validDevice.isExposurePointOfInterestSupported {
                        validDevice.exposurePointOfInterest = pointOfInterest
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
    
    fileprivate var lastFocusRectangle:CAShapeLayer? = nil
    fileprivate var lastFocusPoint: CGPoint? = nil
    fileprivate func _showFocusRectangleAtPoint(_ focusPoint: CGPoint, inLayer layer: CALayer, withBrightness brightness: Float? = nil) {
        
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
        if (brightness != nil) {
            endPath.move(to: CGPoint(x: rect.minX + size.width + size.width / 4, y: rect.minY))
            endPath.addLine(to: CGPoint(x: rect.minX + size.width + size.width / 4, y: rect.minY + size.height))
            
            endPath.move(to: CGPoint(x: rect.minX + size.width + size.width / 4 - size.width / 16, y: rect.minY + size.height - CGFloat(brightness!) * size.height))
            endPath.addLine(to: CGPoint(x: rect.minX + size.width + size.width / 4 + size.width / 16, y: rect.minY + size.height - CGFloat(brightness!) * size.height))
        }
        
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
        lastFocusPoint = focusPoint
        
        CATransaction.begin()
        
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut))
        
        CATransaction.setCompletionBlock {
            if shapeLayer.superlayer != nil {
                shapeLayer.removeFromSuperlayer()
                self.lastFocusRectangle = nil
            }
        }
        if (brightness == nil) {
            let appearPathAnimation = CABasicAnimation(keyPath: "path")
            appearPathAnimation.fromValue = startPath.cgPath
            appearPathAnimation.toValue = endPath.cgPath
            shapeLayer.add(appearPathAnimation, forKey: "path")
            
            let appearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
            appearOpacityAnimation.fromValue = 0.0
            appearOpacityAnimation.toValue = 1.0
            shapeLayer.add(appearOpacityAnimation, forKey: "opacity")
        }
        
        let disappearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
        disappearOpacityAnimation.fromValue = 1.0
        disappearOpacityAnimation.toValue = 0.0
        disappearOpacityAnimation.beginTime = CACurrentMediaTime() + 0.8
        disappearOpacityAnimation.fillMode = CAMediaTimingFillMode.forwards
        disappearOpacityAnimation.isRemovedOnCompletion = false
        shapeLayer.add(disappearOpacityAnimation, forKey: "opacity")
        
        CATransaction.commit()
    }
    
    var exposureValue: Float = 0.1 // EV
    var translationY: Float = 0
    var startPanPointInPreviewLayer: CGPoint?
    
    let exposureDurationPower:Float = 4.0 //the exposure slider gain
    let exposureMininumDuration:Float64 = 1.0/2000.0
    
    @objc fileprivate func _exposureStart(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.view != nil else {return}
        let view = gestureRecognizer.view!
        
        _changeExposureMode(mode: .custom)
        
        let translation = gestureRecognizer.translation(in: view)
        let currentTranslation = translationY + Float(translation.y)
        if (gestureRecognizer.state == .ended) {
            translationY = currentTranslation
        }
        if (currentTranslation < 0) {
            // up - brighter
            exposureValue = 0.5 + min(abs(currentTranslation) / 400, 1) / 2
        } else if (currentTranslation >= 0) {
            // down - lower
            exposureValue = 0.5 - min(abs(currentTranslation) / 400, 1) / 2
        }
        _changeExposureDuration(value: exposureValue)
        
        // UI Visualization
        if (gestureRecognizer.state == .began) {
            if let validPreviewLayer = previewLayer {
                startPanPointInPreviewLayer = view.layer.convert(gestureRecognizer.location(in: view), to: validPreviewLayer)
            }
        }
        
        if let validPreviewLayer = previewLayer, let lastFocusPoint = self.lastFocusPoint {
            _showFocusRectangleAtPoint(lastFocusPoint, inLayer: validPreviewLayer, withBrightness: exposureValue)
        }
    }
    
    // Available modes:
    // .Locked .AutoExpose .ContinuousAutoExposure .Custom
    func _changeExposureMode(mode: AVCaptureDevice.ExposureMode) {
        let device: AVCaptureDevice?
        
        switch cameraDevice {
        case .back:
            device = backCameraDevice
        case .front:
            device = frontCameraDevice
        }
        if (device?.exposureMode == mode) {
            return
        }
        
        do {
            try device?.lockForConfiguration()
        } catch {
            return
        }
        if device?.isExposureModeSupported(mode) == true {
            device?.exposureMode = mode
        }
        device?.unlockForConfiguration()
    }
    
    func _changeExposureDuration(value: Float) {
        if (self.cameraIsSetup) {
            let device: AVCaptureDevice?
            
            switch cameraDevice {
            case .back:
                device = backCameraDevice
            case .front:
                device = frontCameraDevice
            }
            
            do {
                try device?.lockForConfiguration()
            } catch {
                return
            }
            guard let videoDevice = device else {
                return
            }
            
            let p = Float64(pow(value, exposureDurationPower)) // Apply power function to expand slider's low-end range
            let minDurationSeconds = Float64(max(CMTimeGetSeconds(videoDevice.activeFormat.minExposureDuration), exposureMininumDuration))
            let maxDurationSeconds = Float64(CMTimeGetSeconds(videoDevice.activeFormat.maxExposureDuration))
            let newDurationSeconds = Float64(p * (maxDurationSeconds - minDurationSeconds)) + minDurationSeconds // Scale from 0-1 slider range to actual duration
            
            if (videoDevice.exposureMode == .custom) {
                let newExposureTime = CMTimeMakeWithSeconds(Float64(newDurationSeconds), preferredTimescale: 1000*1000*1000)
                videoDevice.setExposureModeCustom(duration: newExposureTime, iso: AVCaptureDevice.currentISO, completionHandler: nil)
            }
        }
    }

    
    // MARK: - CameraManager()
    
    fileprivate func _executeVideoCompletionWithURL(_ url: URL?, error: NSError?) {
        if let validCompletion = videoCompletion {
            validCompletion(url, error)
            videoCompletion = nil
        }
    }
    
    fileprivate func _getMovieOutput() -> AVCaptureMovieFileOutput {
        if movieOutput == nil {
            let newMoviewOutput = AVCaptureMovieFileOutput()
            newMoviewOutput.movieFragmentInterval = CMTime.invalid
            movieOutput = newMoviewOutput
            if let captureSession = captureSession {
                if captureSession.canAddOutput(newMoviewOutput) {
                    captureSession.beginConfiguration()
                    captureSession.addOutput(newMoviewOutput)
                    captureSession.commitConfiguration()
                }
            }
        }

        return movieOutput!
    }
    
    fileprivate func _getStillImageOutput() -> AVCaptureStillImageOutput {
        if let stillImageOutput = stillImageOutput, let connection = stillImageOutput.connection(with: AVMediaType.video),
            connection.isActive {
            return stillImageOutput
        }
        let newStillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput = newStillImageOutput
        if let captureSession = captureSession,
            captureSession.canAddOutput(newStillImageOutput) {
                captureSession.beginConfiguration()
                captureSession.addOutput(newStillImageOutput)
                captureSession.commitConfiguration()
        }
        return newStillImageOutput
    }
    
    @objc fileprivate func _orientationChanged() {
        var currentConnection: AVCaptureConnection?

        switch cameraOutputMode {
        case .stillImage:
            currentConnection = stillImageOutput?.connection(with: AVMediaType.video)
        case .videoOnly, .videoWithMic:
            currentConnection = _getMovieOutput().connection(with: AVMediaType.video)
            if let location = self.locationManager?.latestLocation {
                _setVideoWithGPS(forLocation: location)
            }
        }
        
        if let validPreviewLayer = previewLayer {
            if !shouldKeepViewAtOrientationChanges {
                if let validPreviewLayerConnection = validPreviewLayer.connection,
                    validPreviewLayerConnection.isVideoOrientationSupported {
                        validPreviewLayerConnection.videoOrientation = _currentPreviewVideoOrientation()
                }
            }
            if let validOutputLayerConnection = currentConnection,
                validOutputLayerConnection.isVideoOrientationSupported {
                
                validOutputLayerConnection.videoOrientation = _currentCaptureVideoOrientation()
            }
            if !shouldKeepViewAtOrientationChanges && cameraIsObservingDeviceOrientation {
                DispatchQueue.main.async(execute: { () -> Void in
                    if let validEmbeddingView = self.embeddingView {
                        validPreviewLayer.frame = validEmbeddingView.bounds
                    }
                })
            }
        }
    }
    
    fileprivate func _currentCaptureVideoOrientation() -> AVCaptureVideoOrientation {
        
        if deviceOrientation == .faceDown
            || deviceOrientation == .faceUp
            || deviceOrientation == .unknown {
             return _currentPreviewVideoOrientation()
        }
        
        return _videoOrientation(forDeviceOrientation: deviceOrientation)
    }
    
    
    fileprivate func _currentPreviewDeviceOrientation() -> UIDeviceOrientation {
        if shouldKeepViewAtOrientationChanges {
            return .portrait
        }
        
        return UIDevice.current.orientation
    }

    
    fileprivate func _currentPreviewVideoOrientation() -> AVCaptureVideoOrientation {
        let orientation = _currentPreviewDeviceOrientation()
        return _videoOrientation(forDeviceOrientation: orientation)
    }
    
    open func resetOrientation() {
        //Main purpose is to reset the preview layer orientation.  Problems occur if you are recording landscape, present a modal VC,
        //then turn portriat to dismiss.  The preview view is then stuck in a prior orientation and not redrawn.  Calling this function
        //will then update the orientation of the preview layer.
        _orientationChanged()
    }

    fileprivate func _videoOrientation(forDeviceOrientation deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch deviceOrientation {
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .faceUp:
            /*
             Attempt to keep the existing orientation.  If the device was landscape, then face up
             getting the orientation from the stats bar would fail every other time forcing it
             to default to portrait which would introduce flicker into the preview layer.  This
             would not happen if it was in portrait then face up
            */
            if let validPreviewLayer = previewLayer, let connection = validPreviewLayer.connection  {
                return connection.videoOrientation //Keep the existing orientation
            }
            //Could not get existing orientation, try to get it from stats bar
            return _videoOrientationFromStatusBarOrientation()
        case .faceDown:
            /*
             Attempt to keep the existing orientation.  If the device was landscape, then face down
             getting the orientation from the stats bar would fail every other time forcing it
             to default to portrait which would introduce flicker into the preview layer.  This
             would not happen if it was in portrait then face down
             */
            if let validPreviewLayer = previewLayer, let connection = validPreviewLayer.connection  {
                return connection.videoOrientation //Keep the existing orientation
            }
            //Could not get existing orientation, try to get it from stats bar
            return _videoOrientationFromStatusBarOrientation()
        default:
            return .portrait
        }
    }
    
    fileprivate func _videoOrientationFromStatusBarOrientation() -> AVCaptureVideoOrientation {
        
        var orientation: UIInterfaceOrientation?
       
        DispatchQueue.main.async {
            orientation = UIApplication.shared.statusBarOrientation
        }
        
        /*
         Note - the following would fall into the guard every other call (it is called repeatedly) if the device was
         landscape then face up/down.  Did not seem to fail if in portrait first.
         */
        guard let statusBarOrientation = orientation else {
            return .portrait
        }
        
        switch statusBarOrientation {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }
    
    fileprivate func fixOrientation(withImage image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        var isMirrored = false
        let orientation = image.imageOrientation
        if orientation == .rightMirrored
            || orientation == .leftMirrored
            || orientation == .upMirrored
            || orientation == .downMirrored {
            
            isMirrored = true
        }
        
        let newOrientation = _imageOrientation(forDeviceOrientation: deviceOrientation, isMirrored: isMirrored)
        
        if image.imageOrientation != newOrientation {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: newOrientation)
        }
        
        return image
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
                self._updateIlluminationMode(self.flashMode)
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
            coreMotionManager = CMMotionManager()
            coreMotionManager.accelerometerUpdateInterval = 0.005
            
            if coreMotionManager.isAccelerometerAvailable {
                coreMotionManager.startAccelerometerUpdates(to: OperationQueue(), withHandler:
                    {data, error in
                        
                        guard let acceleration: CMAcceleration = data?.acceleration  else{
                            return
                        }
                        
                        let scaling: CGFloat = CGFloat(1) / CGFloat(( abs(acceleration.x) + abs(acceleration.y)))
                        
                        let x: CGFloat = CGFloat(acceleration.x) * scaling
                        let y: CGFloat = CGFloat(acceleration.y) * scaling
                        
                        if acceleration.z < Double(-0.75) {
                            self.deviceOrientation = .faceUp
                        } else if acceleration.z > Double(0.75) {
                            self.deviceOrientation = .faceDown
                        } else if x < CGFloat(-0.5) {
                            self.deviceOrientation = .landscapeLeft
                        } else if x > CGFloat(0.5) {
                            self.deviceOrientation = .landscapeRight
                        } else if y > CGFloat(0.5) {
                            self.deviceOrientation = .portraitUpsideDown
                        }
                        
                        self._orientationChanged()
                })
                
                cameraIsObservingDeviceOrientation = true
            } else {
                cameraIsObservingDeviceOrientation = false
            }
        }
    }
    
    fileprivate func updateDeviceOrientation(_ orientaion: UIDeviceOrientation) {
        self.deviceOrientation = orientaion
    }
    
    fileprivate func _stopFollowingDeviceOrientation() {
        if cameraIsObservingDeviceOrientation {
            coreMotionManager.stopAccelerometerUpdates()
            cameraIsObservingDeviceOrientation = false
        }
    }
    
    fileprivate func _addPreviewLayerToView(_ view: UIView) {
        embeddingView = view
        attachZoom(view)
        attachFocus(view)
        attachExposure(view)
        
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
        } else if cameraDevice == .front, let frontCameraDevice = frontCameraDevice {
            maxZoom = frontCameraDevice.activeFormat.videoMaxZoomFactor
        }
        
        maxZoomScale = maxZoom
    }
    
    fileprivate func _checkIfCameraIsAvailable() -> CameraState {
        let deviceHasCamera = UIImagePickerController.isCameraDeviceAvailable(UIImagePickerController.CameraDevice.rear) || UIImagePickerController.isCameraDeviceAvailable(UIImagePickerController.CameraDevice.front)
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
            if stillImageOutput == nil {
                _setupOutputs()
            }
            if let validStillImageOutput = stillImageOutput,
                let captureSession = captureSession,
                captureSession.canAddOutput(validStillImageOutput) {
                    captureSession.addOutput(validStillImageOutput)
            }
        case .videoOnly, .videoWithMic:
            let videoMovieOutput = _getMovieOutput()
            if let captureSession = captureSession,
                captureSession.canAddOutput(videoMovieOutput) {
                    captureSession.addOutput(videoMovieOutput)
            }
            
            if newCameraOutputMode == .videoWithMic,
                let validMic = _deviceInputFromDevice(mic) {
                    captureSession?.addInput(validMic)
            }
        }
        captureSession?.commitConfiguration()
        _updateCameraQualityMode(cameraOutputQuality)
        _orientationChanged()
    }
    
    fileprivate func _setupOutputs() {
        if stillImageOutput == nil {
            stillImageOutput = AVCaptureStillImageOutput()
        }
        if movieOutput == nil {
            movieOutput = AVCaptureMovieFileOutput()
            movieOutput?.movieFragmentInterval = CMTime.invalid
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
     Switches between the current and specified camera using a flip animation similar to the one used in the iOS stock camera app.
     */
    
    fileprivate var cameraTransitionView: UIView?
    fileprivate var transitionAnimating = false
    
    open func _doFlipAnimation() {
        
        if transitionAnimating {
            return
        }
        
        if let validEmbeddingView = embeddingView,
            let validPreviewLayer = previewLayer {
                var tempView = UIView()
                
                if CameraManager._blurSupported() {
                    let blurEffect = UIBlurEffect(style: .light)
                    tempView = UIVisualEffectView(effect: blurEffect)
                    tempView.frame = validEmbeddingView.bounds
                } else {
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
                
                DispatchQueue.main.async {
                    self._flipCameraTransitionView()
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
            locationManager.requestWhenInUseAuthorization()
            locationManager.distanceFilter = kCLDistanceFilterNone
            locationManager.headingFilter = 5.0
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
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
        guard let deviceName = String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) else {
            return ""
        }
        return deviceName
    }
    
    fileprivate func _flipCameraTransitionView() {
        
        if let cameraTransitionView = cameraTransitionView {
            
            UIView.transition(with: cameraTransitionView,
                              duration: 0.5,
                              options: UIView.AnimationOptions.transitionFlipFromLeft,
                              animations: nil,
                              completion: { (_) -> Void in
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
                            
            }, completion: { (_) -> Void in
                
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
                if let deviceInput = input as? AVCaptureDeviceInput, deviceInput.device != mic {
                    validCaptureSession.removeInput(deviceInput)
                }
            }
            
            switch cameraDevice {
            case .front:
                if hasFrontCamera {
                    if let validFrontDevice = _deviceInputFromDevice(frontCameraDevice),
                        !inputs.contains(validFrontDevice) {
                            validCaptureSession.addInput(validFrontDevice)
                    }
                }
            case .back:
                if let validBackDevice = _deviceInputFromDevice(backCameraDevice),
                    !inputs.contains(validBackDevice) {
                        validCaptureSession.addInput(validBackDevice)
                }
            }
        }
    }
    
    fileprivate func _updateIlluminationMode(_ mode: CameraFlashMode) {
        if (cameraOutputMode != .stillImage) {
            _updateTorch(mode)
        } else {
            _updateFlash(mode)
        }
    }
    
    fileprivate func _updateTorch(_ torchMode: CameraFlashMode) {
        captureSession?.beginConfiguration()
        defer { captureSession?.commitConfiguration() }
        for captureDevice in AVCaptureDevice.videoDevices  {
            guard let avTorchMode = AVCaptureDevice.TorchMode(rawValue: flashMode.rawValue) else { continue }
            if captureDevice.isTorchModeSupported(avTorchMode) && cameraDevice == .back {
                do {
                    try captureDevice.lockForConfiguration()
                } catch {
                    return
                }
                
                captureDevice.torchMode = avTorchMode
                captureDevice.unlockForConfiguration()
            }
        }
    }
    
    fileprivate func _updateFlash(_ flashMode: CameraFlashMode) {
        captureSession?.beginConfiguration()
        defer { captureSession?.commitConfiguration() }
        for captureDevice in AVCaptureDevice.videoDevices  {
            guard let avFlashMode = AVCaptureDevice.FlashMode(rawValue: flashMode.rawValue) else { continue }
            if captureDevice.isFlashModeSupported(avFlashMode) {
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
            switch newCameraOutputQuality {
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
            if let deviceInput = input as? AVCaptureDeviceInput,
                deviceInput.device == mic {
                    captureSession?.removeInput(deviceInput)
                    break
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
        _stopFollowingDeviceOrientation()
        stopAndRemoveCaptureSession()
    }
}

fileprivate extension AVCaptureDevice {
    fileprivate static var videoDevices: [AVCaptureDevice] {
        return AVCaptureDevice.devices(for: AVMediaType.video)
    }
}

extension PHPhotoLibrary {
    
    // MARK: - Public
    
    // finds or creates an album
    
    func getAlbum(name: String, completion: @escaping (PHAssetCollection) -> ()) {
        if let album = self.findAlbum(name: name) {
            completion(album)
        } else {
            createAlbum(name: name, completion: completion)
        }
    }
    
    func save(imageAtURL: URL, albumName: String?, date: Date = Date(), location: CLLocation? = nil, completion:((PHAsset?) -> ())? = nil) {
        func save() {
            if let albumName = albumName {
                self.getAlbum(name: albumName) { album in
                    self.saveImage(imageAtURL: imageAtURL, album: album, date: date, location: location, completion: completion)
                }
            } else {
                 self.saveImage(imageAtURL: imageAtURL, album: nil, date: date, location: location, completion: completion)
            }
            
        }
        
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            save()
        } else {
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == .authorized {
                    save()
                }
            })
        }
    }
    
    func save(videoAtURL: URL, albumName: String?, date: Date = Date(), location: CLLocation? = nil, completion:((PHAsset?) -> ())? = nil) {
        func save() {
            if let albumName = albumName {
                self.getAlbum(name: albumName) { album in
                    self.saveVideo(videoAtURL: videoAtURL, album: album, date: date, location: location, completion: completion)
                }
            } else {
                self.saveVideo(videoAtURL: videoAtURL, album: nil, date: date, location: location, completion: completion)
            }
            
        }
        
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            save()
        } else {
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == .authorized {
                    save()
                }
            })
        }
    }
    

    // MARK: - Private
    
    fileprivate func findAlbum(name: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", name)
        let fetchResult : PHFetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        guard let photoAlbum = fetchResult.firstObject else {
            return nil
        }
        return photoAlbum
    }
    
    fileprivate func createAlbum(name: String, completion: @escaping (PHAssetCollection) -> ()) {
        var placeholder: PHObjectPlaceholder?
        
        self.performChanges({
            let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholder = createAlbumRequest.placeholderForCreatedAssetCollection
        }, completionHandler: { success, error in
            let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder!.localIdentifier], options: nil)
            completion(fetchResult.firstObject!)
        })
    }
    
    fileprivate func saveImage(imageAtURL: URL, album: PHAssetCollection?, date: Date = Date(), location: CLLocation? = nil, completion:((PHAsset?) -> ())? = nil) {
        var placeholder: PHObjectPlaceholder?
        self.performChanges({
            let createAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: imageAtURL)!
            createAssetRequest.creationDate = date
            createAssetRequest.location = location
            if let album = album {
                guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
                    let photoPlaceholder = createAssetRequest.placeholderForCreatedAsset else { return }
                placeholder = photoPlaceholder
                let fastEnumeration = NSArray(array: [photoPlaceholder] as [PHObjectPlaceholder])
                albumChangeRequest.addAssets(fastEnumeration)

            }
            
        }, completionHandler: { success, error in
            guard let placeholder = placeholder else {
                return
            }
            if success {
                let assets:PHFetchResult<PHAsset> =  PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                let asset:PHAsset? = assets.firstObject
                completion?(asset)
            }
        })
    }

    fileprivate func saveVideo(videoAtURL: URL, album: PHAssetCollection?, date: Date = Date(), location: CLLocation? = nil, completion:((PHAsset?) -> ())? = nil) {
        var placeholder: PHObjectPlaceholder?
        self.performChanges({
            let createAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoAtURL)!
            createAssetRequest.creationDate = date
            createAssetRequest.location = location
            if let album = album {
                guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
                    let photoPlaceholder = createAssetRequest.placeholderForCreatedAsset else { return }
                placeholder = photoPlaceholder
                let fastEnumeration = NSArray(array: [photoPlaceholder] as [PHObjectPlaceholder])
                albumChangeRequest.addAssets(fastEnumeration)
                
            }
            
        }, completionHandler: { success, error in
            guard let placeholder = placeholder else {
                completion?(nil)
                return
            }
            if success {
                let assets:PHFetchResult<PHAsset> =  PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                let asset:PHAsset? = assets.firstObject
                completion?(asset)
            } else {
                completion?(nil)
            }
        })
    }
    
    fileprivate func saveImage(image: UIImage, album: PHAssetCollection, completion:((PHAsset?)->())? = nil) {
        var placeholder: PHObjectPlaceholder?
        self.performChanges({
            let createAssetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            createAssetRequest.creationDate = Date()
            guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
                let photoPlaceholder = createAssetRequest.placeholderForCreatedAsset else { return }
            placeholder = photoPlaceholder
            let fastEnumeration = NSArray(array: [photoPlaceholder] as [PHObjectPlaceholder])
            albumChangeRequest.addAssets(fastEnumeration)
        }, completionHandler: { success, error in
            guard let placeholder = placeholder else {
                completion?(nil)
                return
            }
            if success {
                let assets:PHFetchResult<PHAsset> =  PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                let asset:PHAsset? = assets.firstObject
                completion?(asset)
            } else {
                completion?(nil)
            }
        })
    }
}

