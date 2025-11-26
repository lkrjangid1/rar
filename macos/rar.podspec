#
# macos/rar.podspec
#
# CocoaPods specification for the RAR plugin on macOS.
# Builds the native RAR library using libarchive for RAR support.
#
# Dependencies:
# - libarchive (install via: brew install libarchive)
#
# The native library is built from src/rar_native.c and exposes a C API
# that Dart FFI uses for RAR operations.
#
Pod::Spec.new do |s|
  s.name             = 'rar'
  s.version          = '0.2.1'
  s.summary          = 'Flutter plugin for handling RAR files on macOS.'
  s.description      = <<-DESC
A Flutter plugin for extracting and listing RAR archive contents on macOS.
Uses libarchive for RAR format support via native FFI.
                       DESC
  s.homepage         = 'https://github.com/lkrjangid1/rar'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Lokesh Jangid' => 'lkrjangid@example.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*', '../src/*.{c,h}'
  s.public_header_files = '../src/rar_native.h'

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_ENABLE_MODULES' => 'YES',
    # libarchive paths (Homebrew default location)
    'HEADER_SEARCH_PATHS' => '$(inherited) /opt/homebrew/include /usr/local/include',
    'LIBRARY_SEARCH_PATHS' => '$(inherited) /opt/homebrew/lib /usr/local/lib',
    'OTHER_LDFLAGS' => '$(inherited) -larchive'
  }
  s.swift_version = '5.0'

  # Require libarchive to be installed
  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => '/opt/homebrew/include /usr/local/include',
    'LIBRARY_SEARCH_PATHS' => '/opt/homebrew/lib /usr/local/lib'
  }

  # Build the native library
  s.prepare_command = <<-CMD
    echo "RAR plugin: Checking for libarchive..."
    if [ -f "/opt/homebrew/lib/libarchive.dylib" ] || [ -f "/usr/local/lib/libarchive.dylib" ]; then
      echo "libarchive found"
    else
      echo "Warning: libarchive not found. Install with: brew install libarchive"
    fi
  CMD
end
