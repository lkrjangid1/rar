// lib/src/rar_linux.dart
//
// Linux implementation of the RAR plugin using FFI.
// Communicates with the native librar_native.so library via Dart FFI.
//
// Native Library: UnRAR-based implementation compiled as shared library
// Location: Bundled with the plugin in the Flutter app's lib directory

import 'dart:io';
import '../rar_platform_interface.dart';
import 'rar_desktop_ffi.dart';

/// Linux implementation of [RarPlatform] using FFI.
///
/// This implementation loads the native librar_native.so library and uses
/// FFI to call its functions for RAR extraction and listing.
class RarLinux extends RarPlatform {
  /// Registers this class as the default instance of [RarPlatform] for Linux.
  static void registerWith() {
    RarPlatform.instance = RarLinux();
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
      'message': 'RAR creation is not supported on Linux. Consider using ZIP format instead.',
    };
  }
}
