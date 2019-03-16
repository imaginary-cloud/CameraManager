//
//  CameraEnums.swift
//  CameraManager
//
//  Created by Jelle Alten on 16/03/2019.
//  Copyright © 2019 imaginaryCloud. All rights reserved.
//

import Foundation
import Photos

public enum CameraState {
    case ready, accessDenied, noDeviceFound, notDetermined
}

public enum CameraDevice {
    case front, back
}

public enum CameraFlashMode: Int {
    case off, on, auto
}

public enum CameraOutputMode {
    case stillImage, videoWithMic, videoOnly
}

public enum CameraOutputQuality: Int {
    case low, medium, high
}

public enum CaptureResult {
    case success(content: CaptureContent)
    case failure(Error)

    init(_ image: UIImage) {
        self = .success(content: .image(image))
    }

    init(_ data: Data) {
        self = .success(content: .imageData(data))
    }

    init(_ asset: PHAsset) {
        self = .success(content: .asset(asset))
    }

    var imageData: Data? {
        if case let .success(content) = self {
            return content.asData
        } else {

            return nil
        }
    }
}

public enum CaptureContent {
    case imageData(Data)
    case image(UIImage)
    case asset(PHAsset)
}

extension CaptureContent {

    public var asImage: UIImage? {

        switch self {
        case let .image(image): return image
        case let .imageData(data): return UIImage(data: data)
        case let .asset(asset):
            if let data = getImageData(fromAsset: asset) {
                return UIImage(data: data)
            } else {
                return nil
            }
        }
    }

    public var asData: Data? {

        switch self {
        case let .image(image): return image.jpegData(compressionQuality: 0.8)
        case let .imageData(data): return data
        case let .asset(asset): return getImageData(fromAsset: asset)
        }
    }

    public var asAsset: PHAsset? {

        switch self {
        case .image: return nil
        case .imageData: return nil
        case let .asset(asset): return asset
        }
    }

    private func getImageData(fromAsset asset: PHAsset) -> Data? {

        var imageData: Data? = nil
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.version = .original
        options.isSynchronous = true
        manager.requestImageData(for: asset, options: options) { data, _, _, _ in

            imageData = data
        }
        return imageData
    }
}

public enum CaptureError: Error {

    case noImageData
    case invalidImageData
    case noVideoConnection
    case noSampleBuffer
    case assetNotSaved
}
