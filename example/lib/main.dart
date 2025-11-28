// example/lib/main.dart
//
// Example app demonstrating the RAR plugin on all supported platforms:
// - Android, iOS (mobile)
// - Linux, macOS, Windows (desktop)
// - Web
//
// Features:
// - List RAR archive contents
// - Extract RAR archives
// - Browse extracted files with file tree
// - View file contents (images, text, binary)
// - Password-protected archive support

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rar/rar.dart';

import 'file_browser.dart';

// Conditional imports for platform-specific code
import 'platform_stub.dart'
    if (dart.library.io) 'platform_io.dart'
    if (dart.library.html) 'platform_web.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'Ready';
  String _platformInfo = '';
  List<String> _fileList = [];
  bool _isProcessing = false;
  String? _passwordInput;
  String? _lastExtractPath;
  String? _lastRarFilePath;

  @override
  void initState() {
    super.initState();
    _initPlatform();
    _testListRarContents();
  }

  Future<void> _testListRarContents() async {
    // This is for testing purposes only
    try {
      await Rar.listRarContents(rarFilePath: 'test.rar');
    } catch (e) {
      // ignore: avoid_print
      print('Test error: $e');
    }
  }

  Future<void> _initPlatform() async {
    await requestPlatformPermissions();
    setState(() {
      _platformInfo = getPlatformName();
    });
  }

  Future<String?> _getDestinationPath() async {
    try {
      if (kIsWeb) {
        return '/extracted';
      }
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/rar_extracted';
    } catch (e) {
      return null;
    }
  }

  Future<void> _pickAndExtractRarFile() async {
    setState(() {
      _isProcessing = true;
      _status = 'Selecting RAR file...';
      _fileList = [];
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['rar'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _status = 'No file selected';
          _isProcessing = false;
        });
        return;
      }

      final file = result.files.single;
      String? filePath = file.path;

      if (kIsWeb) {
        if (file.bytes == null) {
          setState(() {
            _status = 'Could not read file data (web)';
            _isProcessing = false;
          });
          return;
        }
        storeWebFileData(file.name, file.bytes!);
        filePath = file.name;
      }

      if (filePath == null) {
        setState(() {
          _status = 'Invalid file path';
          _isProcessing = false;
        });
        return;
      }

      _lastRarFilePath = filePath;

      setState(() {
        _status = 'Selected: ${file.name}';
      });

      final extractPath = await _getDestinationPath();
      if (extractPath == null) {
        setState(() {
          _status = 'Could not access storage directory';
          _isProcessing = false;
        });
        return;
      }

      if (!kIsWeb) {
        await createDirectory(extractPath);
      }

      setState(() {
        _status = 'Extracting to $extractPath...';
      });

      final extractResult = await Rar.extractRarFile(
        rarFilePath: filePath,
        destinationPath: extractPath,
        password: _passwordInput,
      );

      if (extractResult['success'] == true) {
        _lastExtractPath = extractPath;
        setState(() {
          _status = 'Extraction successful: ${extractResult['message']}';
        });

        final files = await listDirectoryContents(extractPath);
        setState(() {
          _fileList = files;
        });
      } else {
        setState(() {
          _status = 'Extraction failed: ${extractResult['message']}';
        });
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _listRarContents() async {
    setState(() {
      _isProcessing = true;
      _status = 'Selecting RAR file...';
      _fileList = [];
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['rar'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _status = 'No file selected';
          _isProcessing = false;
        });
        return;
      }

      final file = result.files.single;
      String? filePath = file.path;

      if (kIsWeb) {
        if (file.bytes == null) {
          setState(() {
            _status = 'Could not read file data (web)';
            _isProcessing = false;
          });
          return;
        }
        storeWebFileData(file.name, file.bytes!);
        filePath = file.name;
      }

      if (filePath == null) {
        setState(() {
          _status = 'Invalid file path';
          _isProcessing = false;
        });
        return;
      }

      _lastRarFilePath = filePath;

      setState(() {
        _status = 'Listing contents of: ${file.name}';
      });

      final listResult = await Rar.listRarContents(
        rarFilePath: filePath,
        password: _passwordInput,
      );

      if (listResult['success'] == true) {
        final files = listResult['files'];
        setState(() {
          _status = 'Listed ${(files as List).length} files in archive';
          _fileList = List<String>.from(files);
        });
      } else {
        setState(() {
          _status = 'Failed to list contents: ${listResult['message']}';
        });
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String password = _passwordInput ?? '';
        return AlertDialog(
          title: const Text('Archive Password'),
          content: TextField(
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Enter password (leave empty for none)',
            ),
            onChanged: (value) => password = value,
            controller: TextEditingController(text: _passwordInput),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _passwordInput = null;
                });
                Navigator.pop(context);
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _passwordInput = password.isEmpty ? null : password;
                });
                Navigator.pop(context);
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  void _openFileBrowser() {
    if (_fileList.isEmpty) return;

    final root = FileNode.buildTree(
      _fileList,
      rootName: _lastRarFilePath?.split('/').last ?? 'Archive',
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FileBrowserPage(
          root: root,
          title: 'Archive Contents',
          onLoadContent: _lastExtractPath != null ? _loadFileContent : null,
        ),
      ),
    );
  }

  Future<Uint8List?> _loadFileContent(String path) async {
    if (_lastExtractPath == null) return null;
    final fullPath = '$_lastExtractPath/$path';
    return await loadFileContent(fullPath);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RAR Plugin Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('RAR Plugin Example'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
              icon: Icon(_passwordInput != null ? Icons.lock : Icons.lock_open),
              tooltip: 'Set password',
              onPressed: _showPasswordDialog,
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Platform info card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getPlatformIcon(),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Platform: $_platformInfo',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        if (_passwordInput != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.lock, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Password set',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Status card
                Card(
                  color: _status.contains('failed') || _status.contains('Error')
                      ? Colors.red.shade50
                      : _status.contains('successful')
                          ? Colors.green.shade50
                          : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(
                          _status.contains('failed') || _status.contains('Error')
                              ? Icons.error_outline
                              : _status.contains('successful')
                                  ? Icons.check_circle_outline
                                  : Icons.info_outline,
                          color: _status.contains('failed') || _status.contains('Error')
                              ? Colors.red
                              : _status.contains('successful')
                                  ? Colors.green
                                  : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _status,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _listRarContents,
                        icon: const Icon(Icons.list),
                        label: const Text('List Contents'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _pickAndExtractRarFile,
                        icon: const Icon(Icons.unarchive),
                        label: const Text('Extract'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Browse button (only visible when files are available)
                if (_fileList.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _openFileBrowser,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Browse Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                    ),
                  ),

                const SizedBox(height: 16),

                // Processing indicator
                if (_isProcessing)
                  const LinearProgressIndicator(),

                const SizedBox(height: 16),

                // File list
                if (_fileList.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Files (${_fileList.length}):',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton.icon(
                        onPressed: _openFileBrowser,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open Browser'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Card(
                      child: ListView.builder(
                        itemCount: _fileList.length,
                        itemBuilder: (context, index) {
                          final fileName = _fileList[index];
                          final isDirectory = fileName.endsWith('/');
                          return ListTile(
                            leading: Icon(
                              isDirectory ? Icons.folder : _getFileIcon(fileName),
                              color: isDirectory ? Colors.amber : Colors.blue,
                            ),
                            title: Text(
                              fileName,
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                            dense: true,
                            onTap: () {
                              if (!isDirectory && _lastExtractPath != null) {
                                _openFileBrowser();
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.archive,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Select a RAR file to list or extract its contents',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Supports RAR v4 and v5 formats',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getPlatformIcon() {
    if (kIsWeb) return Icons.web;
    if (_platformInfo.contains('Android')) return Icons.android;
    if (_platformInfo.contains('iOS')) return Icons.phone_iphone;
    if (_platformInfo.contains('Linux')) return Icons.desktop_windows;
    if (_platformInfo.contains('macOS')) return Icons.laptop_mac;
    if (_platformInfo.contains('Windows')) return Icons.desktop_windows;
    return Icons.devices;
  }

  IconData _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
      case 'md':
      case 'json':
      case 'xml':
        return Icons.text_snippet;
      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
      case 'java':
      case 'c':
      case 'cpp':
        return Icons.code;
      case 'zip':
      case 'rar':
      case 'tar':
      case 'gz':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }
}
