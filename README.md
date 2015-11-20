
# Camera Manager
[![CocoaPods](https://img.shields.io/cocoapods/v/CameraManager.svg)](https://github.com/imaginary-cloud/CameraManager) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

This is a simple Swift class to provide all the configurations you need to create custom camera view in your app. 
It follows orientation change and updates UI accordingly, supports front and rear camera selection, different flash modes, inputs and outputs.
Just drag, drop and use. 

Now it's compatibile with latest Swift syntax if you're using any Swift version prior to 2.0 make sure to use one of the previously tagged releases.

## Installation with CocoaPods

The easiest way to install the CameraManager is with: [CocoaPods](http://cocoapods.org) 

### Podfile

If you want Swift 2.0 syntax use:

```ruby
use_frameworks!

pod 'CameraManager', '~> 2.0’
```

If you want Swift 1.2 syntax use:

```ruby
use_frameworks!

pod 'CameraManager', '~> 1.0.14'
```

## Installation with Carthage

[Carthage](https://github.com/Carthage/Carthage) is another dependency management tool written in Swift.

Add the following line to your Cartfile:

If you want Swift 2.0 syntax use:

```
github "imaginary-cloud/CameraManager" >= 3.0
```

If you want Swift 1.2 syntax use:

```
github "imaginary-cloud/CameraManager" >= 1.0
```

And run `carthage update` to build the dynamic framework.

## How to use
To use it you just add the preview layer to your desired view, you'll get back the state of the camera if it's unavailable, ready or the user denied assess to it.
```swift
let cameraManager
cameraManager.addPreviewLayerToView(self.cameraView)
```
You can set input device to front or back camera:
```swift
cameraManager.cameraDevice = .Front 
cameraManager.cameraDevice = .Back 
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

And flash mode (it will also set corresponding torch mode for video shoot):
```swift
cameraManager.flashMode = .Off
cameraManager.flashMode = .On
cameraManager.flashMode = .Auto
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

You can specify if you want the user to be asked about camera permissions automatically when you first try to use the camera or manually:
```swift
cameraManager.showAccessPermissionPopupAutomatically = false
```

You can even setUp your custom block to handle error messages:
It can be customised to be presented on the Window root view controller, for example.
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
cameraManager.capturePictureWithCompletition({ (image, error) -> Void in
	self.myImage = image             
})
```

To record video you do:
```swift
cameraManager.startRecordingVideo()
cameraManager.stopRecordingVideo({ (videoURL, error) -> Void in
	NSFileManager.defaultManager().copyItemAtURL(videoURL, toURL: self.myVideoURL, error: &error)
})
```

## Support

Supports iOS 8 and above. Xcode 7.0 is required to build the latest code written in Swift 2.0.

## License

Copyright © 2015 ImaginaryCloud, imaginarycloud.com. This library is licensed under the MIT license.
