// lib/src/rar_windows.dart
//
// Windows implementation of the RAR plugin using FFI.
// Communicates with the native rar_native.dll library via Dart FFI.
//
// Native Library: UnRAR-based implementation compiled as DLL
// Location: Bundled with the plugin in the Flutter app's directory

import 'dart:io';
import '../rar_platform_interface.dart';
import 'rar_desktop_ffi.dart';

/// Windows implementation of [RarPlatform] using FFI.
///
/// This implementation loads the native rar_native.dll library and uses
/// FFI to call its functions for RAR extraction and listing.
class RarWindows extends RarPlatform {
  /// Registers this class as the default instance of [RarPlatform] for Windows.
  static void registerWith() {
    RarPlatform.instance = RarWindows();
  }

  @override
  Future<Map<String, dynamic>> extractRarFile({
    required String rarFilePath,
    required String destinationPath,
    String? password,
  }) async {
    // Validate input file exists
    final rarFile = File(rarFilePath);
    if (!await rarFile.exists()) {
      return {
        'success': false,
        'message': 'RAR file not found: $rarFilePath',
      };
    }

    // Create destination directory if it doesn't exist
    final destDir = Directory(destinationPath);
    if (!await destDir.exists()) {
      try {
        await destDir.create(recursive: true);
      } catch (e) {
        return {
          'success': false,
          'message': 'Failed to create destination directory: $e',
        };
      }
    }

    try {
      final (success, message) = RarFfi.instance.extract(
        rarFilePath,
        destinationPath,
        password,
      );

      return {
        'success': success,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'FFI error: $e',
      };
    }
  }

  @override
  Future<Map<String, dynamic>> listRarContents({
    required String rarFilePath,
    String? password,
  }) async {
    // Validate input file exists
    final rarFile = File(rarFilePath);
    if (!await rarFile.exists()) {
      return {
        'success': false,
        'message': 'RAR file not found: $rarFilePath',
        'files': <String>[],
      };
    }

    try {
      final (success, files, message) = RarFfi.instance.list(
        rarFilePath,
        password,
      );

      return {
        'success': success,
        'message': message,
        'files': files,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'FFI error: $e',
        'files': <String>[],
      };
    }
  }

  @override
  Future<Map<String, dynamic>> createRarArchive({
    required String outputPath,
    required List<String> sourcePaths,
    String? password,
    int compressionLevel = 5,
  }) async {
    // RAR creation is not supported due to licensing restrictions
    return {
      'success': false,
      'message': 'RAR creation is not supported on Windows. Consider using ZIP format instead.',
    };
  }
}
