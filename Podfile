platform :ios, '9.0'

target 'SwiftLock' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for SwiftLock
  pod 'zxcvbn-ios', '~> 1.0'  
  pod 'SkyFloatingLabelTextField', '~> 3.0'
  pod 'QRCodeReader.swift', '~> 8.0'
  pod 'MBProgressHUD', '~> 1.0'
  pod 'RFAboutView-Swift', '~> 2.0.1'
  pod 'EAIntroView', '~> 2.12'
  pod 'MiniLockCore', '~> 1.0'

  # MiniLockCore Dev
  # pod 'MiniLockCore', :path => '../MiniLockCore'
end

post_install do |installer|
    require 'fileutils'
    FileUtils.cp_r('Pods/Target Support Files/Pods-SwiftLock/Pods-SwiftLock-acknowledgements.plist', 'SwiftLock/Acknowledgements.plist', :remove_destination => true)
end
