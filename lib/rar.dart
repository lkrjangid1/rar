// Main Dart plugin class for the RAR plugin
// lib/rar.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Rar {
  static const MethodChannel _channel = MethodChannel('com.lkrjangid.rar');

  /// Extract a RAR file to a destination directory
  ///
  /// [rarFilePath] - Path to the RAR file
  /// [destinationPath] - Directory where files will be extracted
  /// [password] - Optional password for encrypted RAR files
  /// Returns a map with 'success' boolean and 'message' string
  static Future<Map<String, dynamic>> extractRarFile({
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

  /// Create a RAR archive from files or directories
  ///
  /// [outputPath] - Path where the RAR file will be created
  /// [sourcePaths] - List of file/directory paths to include in the archive
  /// [password] - Optional password to encrypt the RAR file
  /// [compressionLevel] - Optional compression level (0-9)
  /// Returns a map with 'success' boolean and 'message' string
  static Future<Map<String, dynamic>> createRarArchive({
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

  /// List contents of a RAR file
  ///
  /// [rarFilePath] - Path to the RAR file
  /// [password] - Optional password for encrypted RAR files
  /// Returns a map with 'success' boolean, 'message' string, and 'files' list
  static Future<Map<String, dynamic>> listRarContents({
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
}