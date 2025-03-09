# rar

A Flutter plugin for handling RAR archives on Android and iOS. This plugin allows you to extract RAR files, list their contents, and more.

## Features

- Extract RAR files
- List contents of RAR files
- Support for password-protected RAR archives

## Getting Started

### Installation

Add this to your package's pubspec.yaml file:

```yaml
dependencies:
  rar: latest_version
```

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

## Note on Creating RAR Archives

Creating RAR archives is not supported in this plugin because:

1. RAR is a proprietary format, and creating RAR archives requires the use of proprietary tools
2. There are no reliable, open-source libraries for creating RAR archives on Android and iOS

For creating archives, consider using the ZIP format instead, which has better native support on both platforms.

## License

This plugin is released under the MIT License.

## Third-party Libraries

This plugin depends on:

- [JUnRar](https://github.com/junrar/junrar) for Android (LGPL-3.0 License)
- [UnrarKit](https://github.com/abbeycode/UnrarKit) for iOS (BSD License)