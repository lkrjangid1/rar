// lib/src/rar_method_channel.dart
//
// MethodChannel implementation for the RAR plugin.
// Used on Android and iOS where native implementations communicate via platform channels.

import 'package:flutter/services.dart';
import '../rar_platform_interface.dart';

/// Method channel implementation of [RarPlatform].
///
/// This implementation uses platform channels to communicate with the native
/// Android (JUnRar) and iOS (UnrarKit) implementations.
class RarMethodChannel extends RarPlatform {
  /// The method channel used to interact with the native platform.
  static const MethodChannel _channel = MethodChannel('com.lkrjangid.rar');

  @override
  Future<Map<String, dynamic>> extractRarFile({
    required String rarFilePath,
    required String destinationPath,
    String? password,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'extractRarFile',
        {
          'rarFilePath': rarFilePath,
          'destinationPath': destinationPath,
          'password': password,
        },
      );

      return {
        'success': result?['success'] ?? false,
        'message': result?['message'] ?? 'Unknown error',
      };
    } on PlatformException catch (e) {
      return {
        'success': false,
        'message': 'Platform error: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  @override
  Future<Map<String, dynamic>> listRarContents({
    required String rarFilePath,
    String? password,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'listRarContents',
        {
          'rarFilePath': rarFilePath,
          'password': password,
        },
      );

      return {
        'success': result?['success'] ?? false,
        'message': result?['message'] ?? 'Unknown error',
        'files': result?['files'] ?? <String>[],
      };
    } on PlatformException catch (e) {
      return {
        'success': false,
        'message': 'Platform error: ${e.message}',
        'files': <String>[],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
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
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'createRarArchive',
        {
          'outputPath': outputPath,
          'sourcePaths': sourcePaths,
          'password': password,
          'compressionLevel': compressionLevel,
        },
      );

      return {
        'success': result?['success'] ?? false,
        'message': result?['message'] ?? 'Unknown error',
      };
    } on PlatformException catch (e) {
      return {
        'success': false,
        'message': 'Platform error: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }
}
