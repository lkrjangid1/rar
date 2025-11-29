// example/lib/main.dart
//
// RAR Archive Browser - A two-pane file browser for RAR archives.
// Features:
// - Open RAR button to select archives
// - Two-pane layout on wide screens, tabs on narrow screens (<800px)
// - File tree with expandable folders
// - Content viewer for text and images

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rar/rar.dart';

import 'file_browser.dart';

import 'platform_stub.dart'
    if (dart.library.io) 'platform_io.dart'
    if (dart.library.html) 'platform_web.dart';

void main() {
  runApp(const RarBrowserApp());
}

class RarBrowserApp extends StatelessWidget {
  const RarBrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RAR Browser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const RarBrowserPage(),
    );
  }
}

class RarBrowserPage extends StatefulWidget {
  const RarBrowserPage({super.key});

  @override
  State<RarBrowserPage> createState() => _RarBrowserPageState();
}

class _RarBrowserPageState extends State<RarBrowserPage>
    with SingleTickerProviderStateMixin {
  FileNode? _root;
  FileNode? _selectedFile;
  Uint8List? _fileContent;
  bool _isLoading = false;
  bool _isLoadingContent = false;
  String? _error;
  String? _warning;
  String? _archiveName;
  String? _extractPath;
  String? _password;
  String? _rarVersion;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    requestPlatformPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openRarFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _warning = null;
      _rarVersion = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['rar'],
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final file = result.files.single;
    String? filePath = file.path;

    if (kIsWeb) {
      if (file.bytes == null) {
        setState(() {
          _error = 'Could not read file data';
          _isLoading = false;
        });
        return;
      }
      storeWebFileData(file.name, file.bytes!);
      filePath = file.name;
    }

    if (filePath == null) {
      setState(() {
        _error = 'Invalid file path';
        _isLoading = false;
      });
      return;
    }

    _archiveName = file.name;

    // Get extraction path
    String extractPath;
    if (kIsWeb) {
      extractPath = '/extracted';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      extractPath = '${directory.path}/rar_extracted';
      await createDirectory(extractPath);
    }
    _extractPath = extractPath;

    // Extract the archive to access file contents
    final extractResult = await Rar.extractRarFile(
      rarFilePath: filePath,
      destinationPath: extractPath,
      password: _password,
    );

    if (extractResult['success'] != true) {
      // Try listing contents instead (in case extraction failed but listing works)
      final listResult = await Rar.listRarContents(
        rarFilePath: filePath,
        password: _password,
      );

      if (listResult['success'] == true) {
        final files = List<String>.from(listResult['files'] as List);
        setState(() {
          _root = FileNode.buildTree(files, rootName: file.name);
          _selectedFile = null;
          _fileContent = null;
          _extractPath = null; // Can't load content without extraction
          _isLoading = false;
          _warning = extractResult['message']?.toString();
          _rarVersion = listResult['rarVersion'] as String?;
        });
        return;
      }

      setState(() {
        _error = extractResult['message'] ?? 'Failed to open archive';
        _isLoading = false;
      });
      return;
    }

    // List the extracted files
    final files = await listDirectoryContents(extractPath);

    // Also get the archive structure from the RAR itself for better tree
    final listResult = await Rar.listRarContents(
      rarFilePath: filePath,
      password: _password,
    );

    List<String> archiveFiles;
    if (listResult['success'] == true) {
      archiveFiles = List<String>.from(listResult['files'] as List);
      _rarVersion = listResult['rarVersion'] as String?;
      if (archiveFiles.isEmpty && extractResult['success'] != true) {
        _warning = extractResult['message']?.toString() ??
            listResult['message']?.toString() ??
            'No files were listed from the archive.';
      }
    } else {
      archiveFiles = files;
    }

    setState(() {
      _root = FileNode.buildTree(archiveFiles, rootName: file.name);
      _selectedFile = null;
      _fileContent = null;
      _isLoading = false;
      _rarVersion = _rarVersion ?? listResult['rarVersion'] as String?;
      _warning = _warning ?? listResult['message']?.toString();
    });
  }

  Future<void> _loadFileContent(FileNode node) async {
    if (_extractPath == null) {
      setState(() {
        _fileContent = null;
        _error = 'Content not available (archive not extracted)';
      });
      return;
    }

    setState(() {
      _isLoadingContent = true;
      _selectedFile = node;
      _fileContent = null;
    });

    final fullPath = '$_extractPath/${node.path}';
    final content = await loadFileContent(fullPath);

    setState(() {
      _fileContent = content;
      _isLoadingContent = false;
    });

    // Switch to content tab on narrow screens
    if (_tabController.index == 0 && mounted) {
      _tabController.animateTo(1);
    }
  }

  void _showPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String password = _password ?? '';
        return AlertDialog(
          title: const Text('Archive Password'),
          content: TextField(
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Enter password (leave empty for none)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => password = value,
            controller: TextEditingController(text: _password),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _password = null);
                Navigator.pop(context);
              },
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _password = password.isEmpty ? null : password);
                Navigator.pop(context);
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_archiveName ?? 'RAR Browser'),
        actions: [
          IconButton(
            icon: Icon(_password != null ? Icons.lock : Icons.lock_open),
            tooltip: 'Set password',
            onPressed: _showPasswordDialog,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _openRarFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Open RAR'),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Opening archive...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openRarFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_root == null) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 800) {
          return _buildWideLayout();
        } else {
          return _buildNarrowLayout();
        }
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.archive, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 24),
          Text(
            'RAR Archive Browser',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Open a RAR file to browse its contents',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _openRarFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Open RAR File'),
          ),
          const SizedBox(height: 16),
          Text(
            'Supports RAR v4 and v5 formats',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        SizedBox(width: 320, child: _buildFilesPane()),
        const VerticalDivider(width: 1),
        Expanded(child: _buildContentPane()),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.folder), text: 'Files'),
            Tab(icon: Icon(Icons.preview), text: 'Content'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildFilesPane(), _buildContentPane()],
          ),
        ),
      ],
    );
  }

  Widget _buildFilesPane() {
    if (_root == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_warning != null)
          Container(
            width: double.infinity,
            color: Colors.amber.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _warning!,
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              const Icon(Icons.archive),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _root!.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_rarVersion != null && _rarVersion!.isNotEmpty)
                      Text(
                        _rarVersion!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              Text(
                '${_countFiles(_root!)} files',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: _root!.children
                .map((child) => _buildTreeNode(child, 0))
                .toList(),
          ),
        ),
      ],
    );
  }

  int _countFiles(FileNode node) {
    var count = 0;
    for (final child in node.children) {
      if (child.isDirectory) {
        count += _countFiles(child);
      } else {
        count++;
      }
    }
    return count;
  }

  Widget _buildTreeNode(FileNode node, int depth) {
    final isSelected = _selectedFile == node;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          child: InkWell(
            onTap: () {
              if (node.isDirectory) {
                setState(() => node.isExpanded = !node.isExpanded);
              } else {
                _loadFileContent(node);
              }
            },
            child: Padding(
              padding: EdgeInsets.only(
                left: 12.0 + depth * 20.0,
                top: 10,
                bottom: 10,
                right: 12,
              ),
              child: Row(
                children: [
                  if (node.isDirectory)
                    Icon(
                      node.isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 20,
                      color: Colors.grey,
                    )
                  else
                    const SizedBox(width: 20),
                  const SizedBox(width: 4),
                  Icon(
                    node.isDirectory
                        ? (node.isExpanded ? Icons.folder_open : Icons.folder)
                        : _getFileIcon(node.name),
                    size: 20,
                    color: node.isDirectory
                        ? Colors.amber.shade700
                        : _getFileIconColor(node.name),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.name,
                      style: TextStyle(
                        fontWeight: node.isDirectory
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (node.isDirectory && node.isExpanded)
          ...node.children.map((child) => _buildTreeNode(child, depth + 1)),
      ],
    );
  }

  Widget _buildContentPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Row(
            children: [
              Icon(
                _selectedFile != null
                    ? _getFileIcon(_selectedFile!.name)
                    : Icons.preview,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedFile?.name ?? 'Select a file',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_fileContent != null)
                Text(
                  _formatSize(_fileContent!.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        Expanded(child: _buildContentView()),
      ],
    );
  }

  Widget _buildContentView() {
    if (_selectedFile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Select a file from the tree',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_isLoadingContent) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_extractPath == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Preview not available',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Archive was not extracted',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_fileContent == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Could not load file',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final ext = _selectedFile!.name.split('.').last.toLowerCase();

    // Image files
    if (_isImageExtension(ext)) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.memory(
            _fileContent!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Failed to load image: $error'),
                ],
              );
            },
          ),
        ),
      );
    }

    // Text files
    if (_isTextExtension(ext)) {
      String text;
      try {
        text = String.fromCharCodes(_fileContent!);
      } catch (e) {
        text = _fileContent!.map((b) => String.fromCharCode(b)).join();
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          text,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.5,
          ),
        ),
      );
    }

    // Binary files - show info
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getFileIcon(_selectedFile!.name),
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFile!.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _formatSize(_fileContent!.length),
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Binary file - preview not available',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  bool _isImageExtension(String ext) {
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }

  bool _isTextExtension(String ext) {
    return [
      'txt',
      'md',
      'json',
      'xml',
      'yaml',
      'yml',
      'csv',
      'dart',
      'py',
      'js',
      'ts',
      'java',
      'c',
      'cpp',
      'h',
      'cs',
      'go',
      'rs',
      'swift',
      'kt',
      'rb',
      'php',
      'sh',
      'bash',
      'html',
      'css',
      'scss',
      'less',
      'sql',
      'log',
      'ini',
      'cfg',
      'properties',
      'env',
      'gitignore',
      'dockerfile',
    ].contains(ext);
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
      case 'txt':
      case 'md':
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
        return Icons.text_snippet;
      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
      case 'java':
      case 'c':
      case 'cpp':
      case 'h':
        return Icons.code;
      case 'html':
      case 'css':
        return Icons.web;
      case 'zip':
      case 'rar':
      case 'tar':
      case 'gz':
        return Icons.archive;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Colors.purple;
      case 'pdf':
        return Colors.red;
      case 'dart':
        return Colors.blue;
      case 'py':
        return Colors.green;
      case 'js':
      case 'ts':
        return Colors.amber.shade700;
      case 'html':
        return Colors.orange;
      case 'json':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
