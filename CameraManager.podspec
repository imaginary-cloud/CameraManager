Pod::Spec.new do |s|
  s.name             = "CameraManager"
  s.version          = "1.0.1"
  s.summary          = "This is a simple class to provide all the configurations and you need to create custom camera view in your app. Just drag, drop and use."
  s.homepage         = "https://github.com/imaginary-cloud/CameraManager"
  s.license          = 'MIT'
  s.author           = { "nelanelanela" => "nterlecka@imaginarycloud.com" }
  s.source           = { :git => "https://gist.github.com/2204678.git", :tag => "1.0.1" }
  s.social_media_url = 'http://www.imaginarycloud.com/'
  s.platform         = :ios, '7.0'
  s.requires_arc     = true
  s.source_files     = 'camera/CameraManager.swift'
end
