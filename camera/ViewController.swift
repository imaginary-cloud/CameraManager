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
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.cameraManager.addPreeviewLayerToView(self.cameraView, cameraOutputMode: CameraOutputMode.VideoWithMic)
        self.imageView.hidden = true
    }
    
    @IBAction func changeFlashMode(sender: UIButton)
    {
        self.cameraManager.flashMode = CameraFlashMode.fromRaw((self.cameraManager.flashMode.toRaw()+1)%3)!
    }
    
    @IBAction func recordButtonTapped(sender: UIButton)
    {
        sender.selected = !sender.selected
        sender.backgroundColor = sender.selected ? UIColor.redColor() : UIColor.greenColor()
        if sender.selected {
            self.cameraManager.startRecordingVideo()    
        } else {
            self.cameraManager.stopRecordingVideo()
        }
    }
    
//    @IBAction func viewTapped(sender: UITapGestureRecognizer)
//    {
//        if self.cameraView.hidden == true {
//            self.cameraView.hidden = false
//            self.imageView.hidden = true
//        } else {
//            self.cameraManager.capturePictureWithCompletition({ (image: UIImage) -> Void in
//                self.cameraView.hidden = true
//                self.imageView.hidden = false
//                self.imageView.image = image
//            })
//        }
//    }
    @IBAction func changeCameraDevice(sender: UIButton)
    {
        self.cameraManager.cameraDevice = self.cameraManager.cameraDevice == CameraDevice.Front ? CameraDevice.Back : CameraDevice.Front
    }
}


