# rar

A Flutter plugin for handling RAR archives on **all platforms**: Android, iOS, Linux, macOS, Windows, and Web.

This plugin allows you to extract RAR files, list their contents, and supports password-protected archives.

## Features

- Extract RAR files (v4 and v5 formats)
- List contents of RAR files
- Support for password-protected RAR archives
- Cross-platform support:
  - **Android**: Uses JUnRar (Java)
  - **iOS**: Uses UnrarKit (Objective-C)
  - **Linux/macOS/Windows**: Uses libarchive via native FFI
  - **Web**: Uses WASM-based archive library via JS interop

## Platform Support

| Platform | Extract | List | Password |
|----------|---------|------|----------|
| Android  | ✅      | ✅   | ✅       |
| iOS      | ✅      | ✅   | ✅       |
| Linux    | ✅      | ✅   | ✅       |
| macOS    | ✅      | ✅   | ✅       |
| Windows  | ✅      | ✅   | ✅       |
| Web      | ✅      | ✅   | ✅       |

## Getting Started

### Installation

Add this to your package's pubspec.yaml file:

```yaml
dependencies:
  rar: ^0.2.1
```

### Desktop Dependencies

For desktop platforms, you need to install libarchive:

**Linux (Debian/Ubuntu):**
```bash
sudo apt install libarchive-dev
```

**Linux (Fedora/RHEL):**
```bash
sudo dnf install libarchive-devel
```

**macOS:**
```bash
brew install libarchive
```

**Windows:**
```bash
vcpkg install libarchive:x64-windows
```

### Web Dependencies

The plugin ships the `libarchive.js` WASM runtime so the web demo works even without network access. Add the loader script to your `web/index.html` before `flutter_bootstrap.js`:

```html
<script src="assets/packages/rar/rar_web.js"></script>
```

The script will first try the bundled WASM/worker assets (`libarchive.js`, `worker-bundle.js`), then fall back to a CDN only if the local files are missing.

## Usage

### Extracting a RAR file

```dart
import 'package:rar/rar.dart';

Future<void> extractRarFile() async {
  final result = await Rar.extractRarFile(
    rarFilePath: '/path/to/archive.rar',
    destinationPath: '/path/to/destination/folder',
    password: 'optional_password', // Optional
  );

  if (result['success']) {
    print('Extraction successful: ${result['message']}');
  } else {
    print('Extraction failed: ${result['message']}');
  }
}
```

### Listing RAR contents

```dart
import 'package:rar/rar.dart';

Future<void> listRarContents() async {
  final result = await Rar.listRarContents(
    rarFilePath: '/path/to/archive.rar',
    password: 'optional_password', // Optional
  );

  if (result['success']) {
    print('Files in archive:');
    for (final file in result['files']) {
      print('- $file');
    }
  } else {
    print('Failed to list contents: ${result['message']}');
  }
}
```

### Web Platform Notes

On the web platform, file system access is limited. The plugin uses a virtual file system approach:

1. When selecting files via a file picker, use `withData: true` to get file bytes
2. Store the file data using `RarWeb.storeFileData(path, bytes)`
3. Extracted files are stored in the virtual file system and can be accessed via `RarWeb.getFileData(path)`

```dart
import 'package:rar/rar.dart';

// On web, store file bytes before extraction
if (kIsWeb) {
  RarWeb.storeFileData('archive.rar', fileBytes);
}

final result = await Rar.extractRarFile(
  rarFilePath: 'archive.rar',
  destinationPath: '/extracted',
);

// On web, get extracted file bytes
if (kIsWeb && result['success']) {
  final extractedData = RarWeb.getFileData('/extracted/file.txt');
}
```

## API Reference

### Rar.extractRarFile

```dart
static Future<Map<String, dynamic>> extractRarFile({
  required String rarFilePath,
  required String destinationPath,
  String? password,
})
```

Extracts a RAR file to a destination directory.

**Parameters:**
- `rarFilePath`: Path to the RAR file
- `destinationPath`: Directory where files will be extracted
- `password`: Optional password for encrypted archives

**Returns:** A map containing:
- `success` (bool): Whether the extraction was successful
- `message` (String): Status message or error description

### Rar.listRarContents

```dart
static Future<Map<String, dynamic>> listRarContents({
  required String rarFilePath,
  String? password,
})
```

Lists all files in a RAR archive.

**Parameters:**
- `rarFilePath`: Path to the RAR file
- `password`: Optional password for encrypted archives

**Returns:** A map containing:
- `success` (bool): Whether the listing was successful
- `message` (String): Status message or error description
- `files` (List<String>): List of file names in the archive

## Note on Creating RAR Archives

Creating RAR archives is **not supported** in this plugin because:

1. RAR is a proprietary format, and creating RAR archives requires proprietary tools
2. The RAR compression algorithm is licensed and cannot be freely used for compression
3. Only decompression is allowed under the UnRAR license

For creating archives, consider using the ZIP format instead, which has better native support across all platforms.

## Error Handling

The plugin returns descriptive error messages for common issues:

- **File not found**: The specified RAR file doesn't exist
- **Bad password**: Incorrect password or password required for encrypted archive
- **Bad archive**: Corrupt or invalid RAR file
- **Unknown format**: File is not a valid RAR archive
- **Bad data**: CRC check failed (data corruption)

## License

This plugin is released under the MIT License.

## Third-party Libraries

This plugin uses the following libraries:

| Platform | Library | License |
|----------|---------|---------|
| Android | [JUnRar](https://github.com/junrar/junrar) | LGPL-3.0 |
| iOS | [UnrarKit](https://github.com/abbeycode/UnrarKit) | BSD |
| Desktop | [libarchive](https://libarchive.org/) | BSD |
| Web | [libarchive.js](https://github.com/nicolo-ribaudo/libarchive.js) | MIT |

## Building Native Libraries

This plugin uses native code for RAR extraction. The build system automatically compiles the native libraries when you build your Flutter app.

### Desktop Platforms (FFI)

Desktop platforms use Dart FFI to call native C code compiled with libarchive.

**Linux/macOS/Windows Build Process:**
1. The native C code is located in `src/rar_native.c`
2. Build configuration is in platform-specific files:
   - Linux: `linux/CMakeLists.txt`
   - macOS: `macos/rar.podspec`
   - Windows: `windows/CMakeLists.txt`
3. The native library is automatically built and bundled with your app

**FFI Bindings:**

The FFI bindings in `lib/src/rar_desktop_ffi.dart` are hand-written for better control. If you need to regenerate bindings from the C header, you can use ffigen:

```bash
dart run ffigen
```

### Mobile Platforms (MethodChannel)

Mobile platforms use MethodChannel to communicate with native code:
- **Android**: JUnRar library (Java/Kotlin)
- **iOS**: UnrarKit library (Objective-C/Swift)

### Web Platform (JS Interop)

The web platform uses JavaScript interop with a WASM-based archive library. The WASM library is loaded from CDN at runtime.

## Plugin Architecture

This plugin follows the federated plugin architecture:

```
lib/
  rar.dart                    # Main entry point
  rar_platform_interface.dart # Abstract platform interface
  rar_platform_exports.dart   # Platform exports
  src/
    rar_method_channel.dart   # Mobile implementation
    rar_desktop_ffi.dart      # Desktop FFI bindings
    rar_linux.dart            # Linux platform
    rar_macos.dart            # macOS platform
    rar_windows.dart          # Windows platform
    rar_web.dart              # Web platform
```

## Testing

The plugin includes comprehensive tests for all platforms.

### Running Tests

Use the test runner script:

```bash
# Run unit tests only
./test_runner.sh unit

# Run tests for a specific platform
./test_runner.sh linux
./test_runner.sh macos
./test_runner.sh windows
./test_runner.sh web

# Run all desktop tests
./test_runner.sh desktop

# Run all mobile tests
./test_runner.sh mobile

# Run all tests
./test_runner.sh all
```

### Test Structure

```
test/
  rar_platform_interface_test.dart  # Platform interface unit tests
  rar_test.dart                     # Main Rar class unit tests
example/
  integration_test/
    rar_integration_test.dart       # Integration tests for all platforms
```

## Example App

The example app demonstrates all plugin features across platforms:

- **File picker** for selecting RAR archives
- **Password support** for encrypted archives
- **File browser** with tree view for archive contents
- **Content viewer** supporting:
  - Images (PNG, JPG, GIF, etc.)
  - Text files (TXT, JSON, XML, etc.)
  - Binary files (hex dump view)

Run the example:

```bash
cd example
flutter run -d linux    # or macos, windows, chrome, etc.
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Issues

If you find a bug or want to request a new feature, please open an issue on [GitHub](https://github.com/lkrjangid1/rar/issues).
