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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.cameraManager.addPreeviewLayerToView(self.view)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    @IBAction func viewTapped(sender: UITapGestureRecognizer) {
        self.cameraManager.capturePictureWithCompletition({ (image) -> Void in })
    }
}


