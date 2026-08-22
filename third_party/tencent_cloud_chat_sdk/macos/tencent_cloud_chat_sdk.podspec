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
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.dependency 'TXIMSDK_Plus_Mac', '8.9.7540'
  s.dependency 'HydraAsync'
  s.vendored_frameworks = 'Frameworks/dart_native_imsdk.framework'
  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

  s.prepare_command = <<-CMD
    FRAMEWORK_DIR="#{Dir.pwd}/Frameworks"
    ZIP_PATH="${FRAMEWORK_DIR}/dart_native_imsdk.zip"
    OUTPUT_PRODUCT="${FRAMEWORK_DIR}/dart_native_imsdk.framework"

    mkdir -p "${FRAMEWORK_DIR}"
    rm -rf "${OUTPUT_PRODUCT}"
    unzip "${ZIP_PATH}" -d "${OUTPUT_PRODUCT}"
  CMD

end
