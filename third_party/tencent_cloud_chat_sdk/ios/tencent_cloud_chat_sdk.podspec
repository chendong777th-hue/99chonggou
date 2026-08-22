#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint tencent_cloud_chat_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'tencent_cloud_chat_sdk'
  s.version          = '8.0.0'
  s.summary          = 'Tencent Cloud Chat SDK For Flutter'
  s.description      = 'Tencent Cloud Chat SDK For Flutter'
  s.homepage         = 'https://trtc.io/products/chat'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Tencent' => 'xingchenhe@tencent.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'TXIMSDK_Plus_iOS_XCFramework', "~> 8.9.7545"
  s.dependency 'HydraAsync'
  s.vendored_frameworks = 'Frameworks/dart_native_imsdk.xcframework'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.0'
  s.static_framework = true
end
