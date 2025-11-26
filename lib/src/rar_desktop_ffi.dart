// lib/src/rar_desktop_ffi.dart
//
// FFI bindings for desktop RAR operations.
// Provides a bridge between Dart and the native libarchive-based library.
//
// Native Library: libarchive wrapper (rar_native.so/dylib/dll)
// License: BSD (libarchive)
//
// The native library exposes a simple C API that this file binds to via dart:ffi.
// Each platform (Linux, macOS, Windows) builds and bundles the native library.

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Callback type for receiving file names during listing operation.
typedef ListCallbackNative = Void Function(Pointer<Utf8> filename);

/// Callback type for error reporting from native code.
typedef ErrorCallbackNative = Void Function(Pointer<Utf8> error);

/// Native function signatures for the RAR FFI API.
typedef RarExtractNative = Int32 Function(
  Pointer<Utf8> rarPath,
  Pointer<Utf8> destPath,
  Pointer<Utf8> password,
  Pointer<NativeFunction<ErrorCallbackNative>> errorCallback,
);
typedef RarExtractDart = int Function(
  Pointer<Utf8> rarPath,
  Pointer<Utf8> destPath,
  Pointer<Utf8> password,
  Pointer<NativeFunction<ErrorCallbackNative>> errorCallback,
);

typedef RarListNative = Int32 Function(
  Pointer<Utf8> rarPath,
  Pointer<Utf8> password,
  Pointer<NativeFunction<ListCallbackNative>> listCallback,
  Pointer<NativeFunction<ErrorCallbackNative>> errorCallback,
);
typedef RarListDart = int Function(
  Pointer<Utf8> rarPath,
  Pointer<Utf8> password,
  Pointer<NativeFunction<ListCallbackNative>> listCallback,
  Pointer<NativeFunction<ErrorCallbackNative>> errorCallback,
);

typedef RarGetErrorMessageNative = Pointer<Utf8> Function(Int32 errorCode);
typedef RarGetErrorMessageDart = Pointer<Utf8> Function(int errorCode);

/// Error codes returned by the native RAR library.
class RarError {
  static const int success = 0;
  static const int fileNotFound = 1;
  static const int openError = 2;
  static const int createError = 3;
  static const int memoryError = 4;
  static const int badArchive = 5;
  static const int unknownFormat = 6;
  static const int badPassword = 7;
  static const int badData = 8;
  static const int unknownError = 9;

  static String getMessage(int code) {
    switch (code) {
      case success:
        return 'Success';
      case fileNotFound:
        return 'RAR file not found';
      case openError:
        return 'Failed to open RAR archive';
      case createError:
        return 'Failed to create output file';
      case memoryError:
        return 'Memory allocation error';
      case badArchive:
        return 'Corrupt or invalid RAR archive';
      case unknownFormat:
        return 'Unknown archive format (not a valid RAR file)';
      case badPassword:
        return 'Incorrect password or password required';
      case badData:
        return 'Data error in archive (CRC check failed)';
      default:
        return 'Unknown error (code: $code)';
    }
  }
}

/// Exception thrown when the native RAR library is not available.
class RarLibraryNotAvailableException implements Exception {
  final String message;
  RarLibraryNotAvailableException(this.message);

  @override
  String toString() => 'RarLibraryNotAvailableException: $message';
}

/// FFI bindings class for the native RAR library.
///
/// Loads the platform-specific shared library and provides access to the
/// native functions for RAR extraction and listing.
class RarFfi {
  DynamicLibrary? _lib;
  RarExtractDart? _extract;
  RarListDart? _list;
  RarGetErrorMessageDart? _getErrorMessage;
  String? _loadError;

  /// Singleton instance
  static RarFfi? _instance;

  /// Gets the singleton instance, loading the library if necessary.
  static RarFfi get instance {
    _instance ??= RarFfi._load();
    return _instance!;
  }

  /// Check if the native library is available.
  bool get isAvailable => _lib != null && _extract != null && _list != null;

  /// Get the error message if library loading failed.
  String? get loadError => _loadError;

  RarFfi._load() {
    try {
      _lib = _loadLibrary();
      _extract = _lib!.lookupFunction<RarExtractNative, RarExtractDart>('rar_extract');
      _list = _lib!.lookupFunction<RarListNative, RarListDart>('rar_list');

      // Optional error message function
      try {
        _getErrorMessage = _lib!.lookupFunction<RarGetErrorMessageNative, RarGetErrorMessageDart>('rar_get_error_message');
      } catch (_) {
        _getErrorMessage = null;
      }
    } catch (e) {
      _loadError = e.toString();
      _lib = null;
      _extract = null;
      _list = null;
    }
  }

  /// Load the platform-specific native library.
  static DynamicLibrary _loadLibrary() {
    final List<String> searchPaths = [];

    if (Platform.isLinux) {
      searchPaths.addAll([
        'librar_native.so',
        './librar_native.so',
        '/usr/local/lib/librar_native.so',
        '/usr/lib/librar_native.so',
      ]);
    } else if (Platform.isMacOS) {
      searchPaths.addAll([
        'librar_native.dylib',
        '@executable_path/../Frameworks/librar_native.dylib',
        '@loader_path/../Frameworks/librar_native.dylib',
        './librar_native.dylib',
      ]);
    } else if (Platform.isWindows) {
      searchPaths.addAll([
        'rar_native.dll',
        './rar_native.dll',
      ]);
    } else {
      throw UnsupportedError('Unsupported platform for RAR FFI: ${Platform.operatingSystem}');
    }

    // Try each path
    for (final path in searchPaths) {
      try {
        return DynamicLibrary.open(path);
      } catch (_) {
        // Try next path
      }
    }

    // If all paths failed, throw with helpful message
    throw RarLibraryNotAvailableException(
      'Native RAR library not found. Searched: ${searchPaths.join(", ")}. '
      'Please ensure libarchive is installed and the native library is built.',
    );
  }

  /// Extract a RAR archive to a destination directory.
  ///
  /// Returns a tuple of (success, errorMessage).
  (bool, String) extract(String rarPath, String destPath, String? password) {
    if (!isAvailable) {
      return (false, 'Native library not available: ${_loadError ?? "unknown error"}');
    }

    final rarPathPtr = rarPath.toNativeUtf8();
    final destPathPtr = destPath.toNativeUtf8();
    final passwordPtr = password?.toNativeUtf8() ?? nullptr;

    final errorCallbackPtr = Pointer.fromFunction<ErrorCallbackNative>(
      _staticErrorCallback,
    );

    try {
      _lastError = null;
      final result = _extract!(
        rarPathPtr,
        destPathPtr,
        passwordPtr,
        errorCallbackPtr,
      );

      if (result == RarError.success) {
        return (true, 'Extraction completed successfully');
      } else {
        final message = _lastError ??
            (_getErrorMessage != null
                ? _getErrorMessage!.call(result).toDartString()
                : RarError.getMessage(result));
        return (false, message);
      }
    } finally {
      calloc.free(rarPathPtr);
      calloc.free(destPathPtr);
      if (passwordPtr != nullptr) {
        calloc.free(passwordPtr);
      }
    }
  }

  /// List contents of a RAR archive.
  ///
  /// Returns a tuple of (success, files, errorMessage).
  (bool, List<String>, String) list(String rarPath, String? password) {
    if (!isAvailable) {
      return (false, <String>[], 'Native library not available: ${_loadError ?? "unknown error"}');
    }

    final rarPathPtr = rarPath.toNativeUtf8();
    final passwordPtr = password?.toNativeUtf8() ?? nullptr;

    final listCallbackPtr = Pointer.fromFunction<ListCallbackNative>(
      _staticListCallback,
    );
    final errorCallbackPtr = Pointer.fromFunction<ErrorCallbackNative>(
      _staticErrorCallback,
    );

    try {
      _lastError = null;
      _fileList.clear();

      final result = _list!(
        rarPathPtr,
        passwordPtr,
        listCallbackPtr,
        errorCallbackPtr,
      );

      if (result == RarError.success) {
        return (true, List<String>.from(_fileList), 'Successfully listed RAR contents');
      } else {
        final message = _lastError ??
            (_getErrorMessage != null
                ? _getErrorMessage!.call(result).toDartString()
                : RarError.getMessage(result));
        return (false, <String>[], message);
      }
    } finally {
      calloc.free(rarPathPtr);
      if (passwordPtr != nullptr) {
        calloc.free(passwordPtr);
      }
    }
  }
}

// Static storage for callback data (needed because FFI callbacks must be static)
String? _lastError;
final List<String> _fileList = [];

// Static callback functions (required by FFI - cannot use closures)
void _staticListCallback(Pointer<Utf8> filename) {
  _fileList.add(filename.toDartString());
}

void _staticErrorCallback(Pointer<Utf8> error) {
  _lastError = error.toDartString();
}
