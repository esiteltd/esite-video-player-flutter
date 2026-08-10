#
# Podspec for the eSITE Flutter player.
# Run `pod lib lint esite_flutter_player.podspec` to validate.
#
Pod::Spec.new do |s|
  s.name             = 'esite_flutter_player'
  s.version          = '0.4.1'
  s.summary          = 'Secure video playback for Flutter, backed by the eSITE Video Service.'
  s.description      = <<-DESC
Native iOS player for the eSITE Flutter plugin. Plays unprotected and Lite DRM
(AES-128 encrypted HLS) content through AVPlayer in a dedicated view controller.
                       DESC
  s.homepage         = 'https://github.com/esiteltd/esite-video-player-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'eSITE' => 'support@esite.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
