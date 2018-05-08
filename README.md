
# Camera Manager
[![CocoaPods](https://img.shields.io/cocoapods/v/CameraManager.svg)](https://github.com/imaginary-cloud/CameraManager) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

This is a simple Swift class to provide all the configurations you need to create custom camera view in your app.
It follows orientation change and updates UI accordingly, supports front and rear camera selection, pinch to zoom, tap to focus, different flash modes, inputs and outputs.
Just drag, drop and use.

Now it's compatible with latest Swift syntax, so if you're using any Swift version prior to 4.0 make sure to use one of the previously tagged releases.

## Installation with CocoaPods

The easiest way to install the CameraManager is with: [CocoaPods](http://cocoapods.org)

### Podfile

If you want Swift 4.0 syntax use:

```ruby
use_frameworks!

pod 'CameraManager', '~> 4.0'
```

If you want Swift 3.0 syntax use:

```ruby
use_frameworks!

pod 'CameraManager', '~> 3.2'
```

If you want Swift 2.0 syntax use:

```ruby
use_frameworks!

pod 'CameraManager', '~> 2.2'
```

If you want Swift 1.2 syntax use:

```ruby
use_frameworks!

pod 'CameraManager', '~> 1.0.14'
```

## Installation with Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for managing the distribution of Swift code.

Add `CameraManager` as a dependency in your `Package.swift` file:

```
import PackageDescription

let package = Package(
    dependencies: [
        .Package(url: "https://github.com/imaginary-cloud/CameraManager", majorVersion: 4, minor: 0)
    ]
)
```

## Installation with Carthage

[Carthage](https://github.com/Carthage/Carthage) is another dependency management tool written in Swift.

Add the following line to your Cartfile:

If you want Swift 4.0 syntax use:

```
github "imaginary-cloud/CameraManager" >= 4.0
```

If you want Swift 3.0 syntax use:

```
github "imaginary-cloud/CameraManager" >= 3.2
```

If you want Swift 2.0 syntax use:

```
github "imaginary-cloud/CameraManager" >= 2.2
```

If you want Swift 1.2 syntax use:

```
github "imaginary-cloud/CameraManager" >= 1.0
```

And run `carthage update` to build the dynamic framework.

## How to use
To use it you just add the preview layer to your desired view, you'll get back the state of the camera if it's unavailable, ready or the user denied access to it. Have in mind that in order to retain the AVCaptureSession you will need to retain cameraManager instance somewhere, ex. as an instance constant.
```swift
let cameraManager = CameraManager()
cameraManager.addPreviewLayerToView(self.cameraView)
```
You can set input device to front or back camera:
```swift
cameraManager.cameraDevice = .Front
cameraManager.cameraDevice = .Back
```

You can specify if the front camera image should be horizontally fliped:

```swift
cameraManager.shouldFlipFrontCameraImage = true
```

You can enable or disable gestures on camera preview:

```swift
cameraManager.shouldEnableTapToFocus = true
cameraManager.shouldEnablePinchToZoom = true
```

You can set output format to Image, video or video with audio:

```swift
cameraManager.cameraOutputMode = .StillImage
cameraManager.cameraOutputMode = .VideoWithMic
cameraManager.cameraOutputMode = .VideoOnly
```

You can set the quality:
```swift
cameraManager.cameraOutputQuality = .Low
cameraManager.cameraOutputQuality = .Medium
cameraManager.cameraOutputQuality = .High
```

You can specifiy the focus and exposure mode:
```swift
cameraManager.focusMode = .continuousAutoFocus 
cameraManager.exposureMode = .continuousAutoExposure 
```

You can change the flash mode (it will also set corresponding flash mode):
```swift
cameraManager.flashMode = .Off
cameraManager.flashMode = .On
cameraManager.flashMode = .Auto
```

To enable location services for storing in Camera Roll. Default is false:
```
cameraManager.shouldUseLocationServices = true
```

To check if the device supports flash call:
```swift
cameraManager.hasFlash
```

To change flash mode to the next available one you can use this handy function which will also return current value for you to update the UI accordingly:
```swift
cameraManager.changeFlashMode()
```

You can specify if you want to save the files to phone library:
```swift
cameraManager.writeFilesToPhoneLibrary = true
```

You can specify if you want to disable animations:
```swift
cameraManager.animateShutter = false
cameraManager.animateCameraDeviceChange = false
```

You can specify if you want the user to be asked about camera permissions automatically when you first try to use the camera or manually:
```swift
cameraManager.showAccessPermissionPopupAutomatically = false
```

You can even setUp your custom block to handle error messages:
It can be customized to be presented on the Window root view controller, for example.
```swift
cameraManager.showErrorBlock = { (erTitle: String, erMessage: String) -> Void in
    var alertController = UIAlertController(title: erTitle, message: erMessage, preferredStyle: .Alert)
    alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (alertAction) -> Void in
    }))

    let topController = UIApplication.sharedApplication().keyWindow?.rootViewController

    if (topController != nil) {
        topController?.presentViewController(alertController, animated: true, completion: { () -> Void in
            //
        })
    }

}
```

To shoot image all you need to do is call:
```swift
cameraManager.capturePictureWithCompletion({ (image, error) -> Void in
	self.myImage = image             
})
```

To record video you do:
```swift
cameraManager.startRecordingVideo()
cameraManager.stopVideoRecording({ (videoURL, error) -> Void in
	NSFileManager.defaultManager().copyItemAtURL(videoURL, toURL: self.myVideoURL, error: &error)
})
```

## Support

Supports iOS 8 and above. Xcode 9.0 is required to build the latest code written in Swift 4.0.

## License

Copyright © 2018 Imaginary Cloud, www.imaginarycloud.com. This library is licensed under the MIT license.
