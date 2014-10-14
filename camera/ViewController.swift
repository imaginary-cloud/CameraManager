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
            self.cameraManager.stopRecordingVideo({ (videoURL) -> Void in
                println("YEEEEEEY ! ! ")
                println(videoURL)
            })
        }
    }
    
    @IBAction func changeCameraDevice(sender: UIButton)
    {
        self.cameraManager.cameraDevice = self.cameraManager.cameraDevice == CameraDevice.Front ? CameraDevice.Back : CameraDevice.Front
    }
}


