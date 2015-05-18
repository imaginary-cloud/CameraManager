
# Camera Manager
[![CocoaPods](https://img.shields.io/cocoapods/v/CameraManager.svg)](https://github.com/imaginary-cloud/CameraManager) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

This is a simple Swift class to provide all the configurations you need to create custom camera view in your app. 
It follows orientation change and updates UI accordingly, supports front and rear camera selection, different flash modes, inputs and outputs.
Just drag, drop and use. 

## Installation with CocoaPods

The easiest way to install the CameraManager is with: [CocoaPods](http://cocoapods.org) 

### Podfile

```ruby
use_frameworks!

pod 'CameraManager', '~> 1.0'
```

## Installation with Carthage

[Carthage](https://github.com/Carthage/Carthage) is another dependency management tool written in Swift.

Add the following line to your Cartfile:

```
github "imaginary-cloud/CameraManager" >= 1.0
```
And run `carthage update` to build the dynamic framework.

## How to use
To use it you just add the preview layer to your desired view, you'll get back the state of the camera if it's unavailable, ready or the user denied assess to it.
```swift
CameraManager.sharedInstance.addPreviewLayerToView(self.cameraView)
```
You can set input device to front or back camera:
```swift
CameraManager.sharedInstance.cameraDevice = .Front 
CameraManager.sharedInstance.cameraDevice = .Back 
```

You can set output format to Image, video or video with audio:
```swift
CameraManager.sharedInstance.cameraOutputMode = .StillImage
CameraManager.sharedInstance.cameraOutputMode = .VideoWithMic
CameraManager.sharedInstance.cameraOutputMode = .VideoOnly
```

You can set the quality:
```swift
CameraManager.sharedInstance.cameraOutputQuality = .Low
CameraManager.sharedInstance.cameraOutputQuality = .Medium
CameraManager.sharedInstance.cameraOutputQuality = .High
```

And flash mode (it will also set corresponding torch mode for video shoot):
```swift
CameraManager.sharedInstance.flashMode = .Off
CameraManager.sharedInstance.flashMode = .On
CameraManager.sharedInstance.flashMode = .Auto
```

To check if the device supports flash call:
```swift
CameraManager.sharedInstance.hasFlash
```

To change flash mode to the next available one you can use this handy function which will also return current value for you to update the UI accordingly:
```swift
CameraManager.sharedInstance.changeFlashMode()
```


You can specify if you want to save the files to phone library:
```swift
CameraManager.sharedInstance.writeFilesToPhoneLibrary = true
```

You can specify if you want the user to be asked about camera permissions automatically when you first try to use the camera or manually:
```swift
CameraManager.sharedInstance.showAccessPermissionPopupAutomatically = false
```

You can even setUp your custom block to handle error messages:
```swift
CameraManager.sharedInstance.showErrorBlock = { (erTitle: String, erMessage: String) -> Void in
    UIAlertView(title: erTitle, message: erMessage, delegate: nil, cancelButtonTitle: "OK").show()
}
```

To shoot image all you need to do is call:
```swift
CameraManager.sharedInstance.capturePictureWithCompletition({ (image, error) -> Void in
	self.myImage = image             
})
```

To record video you do:
```swift
CameraManager.sharedInstance.startRecordingVideo()
CameraManager.sharedInstance.stopRecordingVideo({ (videoURL, error) -> Void in
	NSFileManager.defaultManager().copyItemAtURL(videoURL, toURL: self.myVideoURL, error: &error)
})
```

## Support

Supports iOS 8 and above. Xcode 6.3 is required to build the latest code written in Swift 1.2.

## License

Copyright © 2015 ImaginaryCloud, imaginarycloud.com. This library is licensed under the MIT license.
