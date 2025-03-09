#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint rar.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'rar'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'https://github.com/lkrjangid1/'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'lkrjangid@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # ~> Version 3.19.0 up to, but not including, 4.0.0
  s.dependency 'UnrarKit', '~> 2.9'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
