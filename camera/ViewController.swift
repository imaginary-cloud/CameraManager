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
        self.cameraManager.cameraDevice = .Front
        self.imageView.hidden = true
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
        switch (self.cameraManager.cameraDevice) {
        case .Front:
            sender.setTitle("Front", forState: UIControlState.Normal)
        case .Back:
            sender.setTitle("Back", forState: UIControlState.Normal)
        }
    }
}


