Pod::Spec.new do |s|
  s.name             = "CameraManager"
  s.version          = "5.0.0"
  s.summary          = "This is a simple Swift class to provide all the configurations you need to create custom camera view in your app. Just drag, drop and use."
  s.requires_arc     = true
  s.homepage         = "https://github.com/imaginary-cloud/CameraManager"
  s.license          = 'MIT'
  s.author           = { "torrao" => "rtorrao@imaginarycloud.com" }
  s.source           = { :git => "https://github.com/imaginary-cloud/CameraManager.git", :tag => "5.0.0" }
  s.social_media_url = 'http://www.imaginarycloud.com/'
  s.platform         = :ios, '9.0'
  s.pod_target_xcconfig = { "SWIFT_VERSION" => "5.2" }
  s.swift_version    = '5.2'
  s.source_files     = 'Sources/CameraManager.swift'
end
