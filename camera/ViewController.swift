//
//  ViewController.swift
//  camera
//
//  Created by Natalia Terlecka on 10/10/14.
//  Copyright (c) 2014 imaginaryCloud. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    let cameraManager = CameraManager.sharedInstance
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var cameraButton: UIButton!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()        
        self.cameraManager.addPreviewLayerToView(self.cameraView, newCameraOutputMode: CameraOutputMode.VideoWithMic)
        self.cameraManager.cameraDevice = .Front
        self.imageView.hidden = true
        CameraManager.sharedInstance.showErrorBlock = { (erTitle: String, erMessage: String) -> Void in
            UIAlertView(title: erTitle, message: erMessage, delegate: nil, cancelButtonTitle: "OK").show()
        }
    }
    
    @IBAction func changeFlashMode(sender: UIButton)
    {
        self.cameraManager.flashMode = CameraFlashMode.fromRaw((self.cameraManager.flashMode.toRaw()+1)%3)!
        switch (self.cameraManager.flashMode) {
        case .Off:
            sender.setTitle("Flash Off", forState: UIControlState.Normal)
        case .On:
            sender.setTitle("Flash On", forState: UIControlState.Normal)
        case .Auto:
            sender.setTitle("Flash Auto", forState: UIControlState.Normal)
        }
    }
    
    @IBAction func recordButtonTapped(sender: UIButton)
    {
        switch (self.cameraManager.cameraOutputMode) {
        case .StillImage:
            self.cameraManager.capturePictureWithCompletition({ (image) -> Void in
                
            })
        case .VideoWithMic, .VideoOnly:
            sender.selected = !sender.selected
            sender.setTitle(" ", forState: UIControlState.Selected)
            sender.backgroundColor = sender.selected ? UIColor.redColor() : UIColor.greenColor()
            if sender.selected {
                self.cameraManager.startRecordingVideo()
            } else {
                self.cameraManager.stopRecordingVideo({ (videoURL) -> Void in
                    println(videoURL)
                })
            }
        }
    }
    
    @IBAction func outputModeButtonTapped(sender: UIButton)
    {
        self.cameraManager.cameraOutputMode = self.cameraManager.cameraOutputMode == CameraOutputMode.VideoWithMic ? CameraOutputMode.StillImage : CameraOutputMode.VideoWithMic
        switch (self.cameraManager.cameraOutputMode) {
        case .StillImage:
            self.cameraButton.selected = false
            self.cameraButton.backgroundColor = UIColor.greenColor()
            sender.setTitle("Image", forState: UIControlState.Normal)
        case .VideoWithMic, .VideoOnly:
            sender.setTitle("Video", forState: UIControlState.Normal)
        }
    }
    
    @IBAction func changeCameraDevice(sender: UIButton)
    {
        self.cameraManager.cameraDevice = self.cameraManager.cameraDevice == CameraDevice.Front ? CameraDevice.Back : CameraDevice.Front
        switch (self.cameraManager.cameraDevice) {
        case .Front:
            sender.setTitle("Front", forState: UIControlState.Normal)
        case .Back:
            sender.setTitle("Back", forState: UIControlState.Normal)
        }
    }
}


