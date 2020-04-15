//
//  ImageViewController.swift
//  camera
//
//  Created by Natalia Terlecka on 13/01/15.
//  Copyright (c) 2015 Imaginary Cloud. All rights reserved.
//

import CameraManager
import UIKit

class ImageViewController: UIViewController {
    var image: UIImage?
    var cameraManager: CameraManager?
    @IBOutlet var imageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.isHidden = true

        guard let validImage = image else {
            return
        }

        imageView.image = validImage

        if cameraManager?.cameraDevice == .front {
            switch validImage.imageOrientation {
            case .up, .down:
                imageView.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
            default:
                break
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func closeButtonTapped(_: Any) {
        navigationController?.popViewController(animated: true)
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }

    override var shouldAutorotate: Bool {
        return false
    }
}
