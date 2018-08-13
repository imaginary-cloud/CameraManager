
# Camera Manager
[![CocoaPods](https://img.shields.io/cocoapods/v/CameraManager.svg)](https://github.com/imaginary-cloud/CameraManager) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

This is a simple Swift class to provide all the configurations you need to create custom camera view in your app.
It follows orientation change and updates UI accordingly, supports front and rear camera selection, pinch to zoom, tap to focus, exposure slider, different flash modes, inputs and outputs.
Just drag, drop and use.

## Installation with CocoaPods

The easiest way to install the CameraManager is with [CocoaPods](http://cocoapods.org)

### Podfile

```ruby
use_frameworks!

pod 'CameraManager', '~> 4.3'
``` 

## Installation with Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for managing the distribution of Swift code.

Add `CameraManager` as a dependency in your `Package.swift` file:

```
import PackageDescription

let package = Package(
    dependencies: [
        .Package(url: "https://github.com/imaginary-cloud/CameraManager", majorVersion: 4, minor: 3)
    ]
)
```

## Installation with Carthage

[Carthage](https://github.com/Carthage/Carthage) is another dependency management tool written in Swift.

Add the following line to your Cartfile:

```
github "imaginary-cloud/CameraManager" >= 4.3
```

And run `carthage update` to build the dynamic framework.

## How to use
To use it you just add the preview layer to your desired view, you'll get back the state of the camera if it's unavailable, ready or the user denied access to it. Have in mind that in order to retain the AVCaptureSession you will need to retain cameraManager instance somewhere, ex. as an instance constant.
```swift
let cameraManager = CameraManager()
cameraManager.addPreviewLayerToView(self.cameraView)
```

To shoot image all you need to do is call:
```swift
cameraManager.capturePictureWithCompletion({ (image, error) -> Void in
    self.myImage = image             
})
```

To record video you call:
```swift
cameraManager.startRecordingVideo()
cameraManager.stopVideoRecording({ (videoURL, error) -> Void in
    NSFileManager.defaultManager().copyItemAtURL(videoURL, toURL: self.myVideoURL, error: &error)
})
```

To zoom in manually:
```swift
let zoomScale = CGFloat(2.0)
cameraManager.zoom(zoomScale)
```

### Properties

You can set input device to front or back camera. `(Default: .Back)`
```swift
cameraManager.cameraDevice = .Front || .Back
```

You can specify if the front camera image should be horizontally fliped. `(Default: false)`

```swift
cameraManager.shouldFlipFrontCameraImage = true || false
```

You can enable or disable gestures on camera preview. `(Default: true)`

```swift
cameraManager.shouldEnableTapToFocus = true || false
cameraManager.shouldEnablePinchToZoom = true || false
cameraManager.shouldEnableExposure = true || false
```

You can set output format to Image, video or video with audio. `(Default: .StillImage)`

```swift
cameraManager.cameraOutputMode = .StillImage || .VideoWithMic || .VideoOnly
```

You can set the quality. `(Default: .High)`
```swift
cameraManager.cameraOutputQuality = .Low || .Medium || .High
```

You can specify the focus mode. `(Default: .continuousAutoFocus)`
```swift
cameraManager.focusMode = .autoFocus || .continuousAutoFocus || .locked
```

You can specifiy the exposure mode. `(Default: .continuousAutoExposure)`
```swift
cameraManager.exposureMode = .autoExpose || .continuousAutoExposure || .locked || .custom
```

You can change the flash mode (it will also set corresponding flash mode). `(Default: .Off)`
```swift
cameraManager.flashMode = .Off || .On || .Auto
```

You can specify the stabilisation mode to be used during a video record session. `(Default: .auto)`
```swift
cameraManger.videoStabilisationMode = .auto || .cinematic
```

You can enable location services for storing in Camera Roll. `(Default: false)`
```swift
cameraManager.shouldUseLocationServices = true || false
```

You can specify if you want to save the files to phone library. `(Default: true)`
```swift
cameraManager.writeFilesToPhoneLibrary = true || false
```

You can specify the album names for image and video recordings.
```swift 
cameraManager.imageAlbumName =  "Image Album Name" 
cameraManager.videoAlbumName =  "Video Album Name" 
```

You can specify if you want to disable animations. `(Default: true)`
```swift
cameraManager.animateShutter = true || false
cameraManager.animateCameraDeviceChange = true || false
```

You can specify if you want the user to be asked about camera permissions automatically when you first try to use the camera or manually. `(Default: true)`
```swift
cameraManager.showAccessPermissionPopupAutomatically = true || false
```

To check if the device supports flash call:
```swift
cameraManager.hasFlash
```

To change flash mode to the next available one you can use this handy function which will also return current value for you to update the UI accordingly:
```swift
cameraManager.changeFlashMode()
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

## Support

Supports iOS 9 and above. Xcode 9.0 is required to build the latest code written in Swift 4.0.


Now it's compatible with latest Swift syntax, so if you're using any Swift version prior to 4.0 make sure to use one of the previously tagged releases
(i.e for Swift 3.0 see [v3.2.0](https://github.com/imaginary-cloud/CameraManager/tree/3.2.0)).

## License

Copyright © 2010-2018 [Imaginary Cloud](https://www.imaginarycloud.com). This library is licensed under the MIT license.

## About Imaginary Cloud

![Imaginary Cloud](https://s3.eu-central-1.amazonaws.com/imaginary-images/Logo_IC_readme.svg)

We apply our own Product Design Process to bring great digital products to life. Visit [our website](https://www.imaginarycloud.com) to find out about our other projects or [contact us](https://www.imaginarycloud.com/contacts) if there's an idea that you want to turn into an outstanding product, we'll take it from there!
