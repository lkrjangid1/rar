// example/lib/main.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rar/rar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'Idle';
  List<String> _fileList = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.storage,
      ].request();
    }
  }

  Future<void> _pickAndExtractRarFile() async {
    setState(() {
      _isProcessing = true;
      _status = 'Selecting file...';
    });

    try {
      // Pick a RAR file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg'],
      );

      if (result == null) {
        setState(() {
          _status = 'No file selected';
          _isProcessing = false;
        });
        return;
      }

      final path = result.files.single.path;
      if (path == null) {
        setState(() {
          _status = 'Invalid file path';
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _status = 'Selected: ${result.files.single.name}';
      });

      // Get the destination directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        setState(() {
          _status = 'Could not access storage directory';
          _isProcessing = false;
        });
        return;
      }

      final extractPath = '${directory.path}/extracted';

      // Create the directory if it doesn't exist
      final extractDir = Directory(extractPath);
      if (!await extractDir.exists()) {
        await extractDir.create(recursive: true);
      }

      setState(() {
        _status = 'Extracting to $extractPath...';
      });

      // Extract the RAR file
      final extractResult = await Rar.extractRarFile(
        rarFilePath: path,
        destinationPath: extractPath,
      );

      if (extractResult['success']) {
        setState(() {
          _status = 'Extraction successful: ${extractResult['message']}';
        });

        // List the extracted files
        final dir = Directory(extractPath);
        final List<FileSystemEntity> entities = await dir.list().toList();
        setState(() {
          _fileList = entities.map((e) => e.path.split('/').last).toList();
        });
      } else {
        setState(() {
          _status = 'Extraction failed: ${extractResult['message']}';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _listRarContents() async {
    setState(() {
      _isProcessing = true;
      _status = 'Selecting file...';
    });

    try {
      // Pick a RAR file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['rar'],
      );

      if (result == null) {
        setState(() {
          _status = 'No file selected';
          _isProcessing = false;
        });
        return;
      }

      final path = result.files.single.path;
      if (path == null) {
        setState(() {
          _status = 'Invalid file path';
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _status = 'Listing contents of: ${result.files.single.name}';
      });

      // List RAR contents
      final listResult = await Rar.listRarContents(
        rarFilePath: path,
      );

      if (listResult['success']) {
        setState(() {
          _status = 'Listed RAR contents successfully';
          _fileList = List<String>.from(listResult['files']);
        });
      } else {
        setState(() {
          _status = 'Failed to list contents: ${listResult['message']}';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('RAR Plugin Example'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _status,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _pickAndExtractRarFile,
                  child: const Text('Extract RAR File'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _listRarContents,
                  child: const Text('List RAR Contents'),
                ),
                const SizedBox(height: 20),
                if (_fileList.isNotEmpty) ...[
                  const Text(
                    'Files:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _fileList.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(_fileList[index]),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
