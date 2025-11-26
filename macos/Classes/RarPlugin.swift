// macos/Classes/RarPlugin.swift
//
// Flutter plugin registration for macOS.
// Note: The actual RAR operations are handled via FFI (rar_desktop_ffi.dart),
// not through MethodChannel. This plugin file is required by Flutter's plugin
// system for registration purposes.

import Cocoa
import FlutterMacOS

public class RarPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.lkrjangid.rar", binaryMessenger: registrar.messenger)
    let instance = RarPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS (Desktop FFI) " + ProcessInfo.processInfo.operatingSystemVersionString)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
