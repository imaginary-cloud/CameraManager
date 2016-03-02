// Package.swift
//
// Copyright © 2016 ImaginaryCloud, imaginarycloud.com. This library is licensed under the MIT license.

import PackageDescription

let package = Package(
  name: "CameraManager",
  targets: [
        Target(name: "camera", dependencies: [.Target(name: "CameraManager")])
    ]
)
