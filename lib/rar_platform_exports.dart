// lib/rar_platform_exports.dart
//
// Barrel file that exports all platform-specific implementations.
// These are used by Flutter's plugin registration system.

export 'src/rar_method_channel.dart';
export 'src/rar_linux.dart' if (dart.library.io) 'src/rar_linux.dart';
export 'src/rar_macos.dart' if (dart.library.io) 'src/rar_macos.dart';
export 'src/rar_windows.dart' if (dart.library.io) 'src/rar_windows.dart';
export 'src/rar_web.dart' if (dart.library.html) 'src/rar_web.dart';
