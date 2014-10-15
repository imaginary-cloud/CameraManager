
####Camera Manager

V1.0.0 (10-Oct-2014)

####About
This is a simple class to provide all the configurations you need to create custom camera view in your app.
Just drag, drop and use. 

####How to use
To use it you just add the preview layer to your desired view 
```swift
CameraManager.sharedInstance.addPreeviewLayerToView(self.cameraView)
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

And flash mode:
```swift
CameraManager.sharedInstance.flashMode = .Off
CameraManager.sharedInstance.flashMode = .On
CameraManager.sharedInstance.flashMode = .Auto
```

You can even setUp your custom block to handle error messages:
```swift
CameraManager.sharedInstance.showErrorBlock = { (erTitle: String, erMessage: String) -> Void in
    UIAlertView(title: erTitle, message: erMessage, delegate: nil, cancelButtonTitle: "OK").show()
}
```

To shoot image all you need to do is call:
```swift
CameraManager.sharedInstance.capturePictureWithCompletition({ (image) -> Void in
	self.myImage = image             
})
```

To record video you do:
```swift
CameraManager.sharedInstance.startRecordingVideo()
CameraManager.sharedInstance.stopRecordingVideo({ (videoURL) -> Void in
	NSFileManager.defaultManager().copyItemAtURL(videoURL, toURL: self.myVideoURL, error: &error)
})
```

####Support

Supports iOS 7 and above

####License

Copyright © 2014 ImaginaryCloud, imaginarycloud.com. This plugin is licensed under the MIT license.
