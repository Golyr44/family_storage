import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Семейное хранилище',
      theme: ThemeData.dark(),
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<FileSystemEntity> _files = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // Папка для хранения файлов в приложении
  Future<Directory> _getAppStorageDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final storageDir = Directory('${dir.path}/family_storage');
    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }
    return storageDir;
  }

  // Загрузка списка файлов
  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final dir = await _getAppStorageDir();
      final files = await dir.list().toList();
      setState(() {
        _files = files.where((file) {
          final ext = file.path.split('.').last.toLowerCase();
          return ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov', 'avi', 'mkv'].contains(ext);
        }).toList();
      });
    } catch (e) {
      print('Ошибка загрузки файлов: $e');
    }
    setState(() => _isLoading = false);
  }

  // Загрузка нового файла
  Future<void> _uploadFile() async {
    try {
      // Запрашиваем разрешения
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нужны разрешения для доступа к файлам!')),
        );
        return;
      }

      // Показываем диалог выбора (фото или видео)
      final type = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Выберите тип'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('Фото'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Видео'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Снять фото/видео'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
      
      if (type == null) return;

      XFile? pickedFile;
      if (type == ImageSource.gallery) {
        pickedFile = await _picker.pickMedia();
      } else if (type == ImageSource.camera) {
        pickedFile = await _picker.pickImage(source: ImageSource.camera);
      }

      if (pickedFile != null) {
        final storageDir = await _getAppStorageDir();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
        final newPath = '${storageDir.path}/$fileName';
        
        // Копируем файл в хранилище приложения
        final file = File(pickedFile.path);
        await file.copy(newPath);
        
        setState(() {
          _files.add(File(newPath));
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Файл загружен: $fileName')),
        );
      }
    } catch (e) {
      print('Ошибка загрузки: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: $e')),
      );
    }
  }

  // Удаление файла
  Future<void> _deleteFile(FileSystemEntity file) async {
    try {
      await file.delete();
      setState(() {
        _files.remove(file);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл удалён')),
      );
    } catch (e) {
      print('Ошибка удаления: $e');
    }
  }

  // Сохранение файла на телефон
  Future<void> _saveFileToDevice(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last;
      
      // Сохраняем в галерею телефона
      if (['jpg', 'jpeg', 'png', 'gif'].contains(ext.toLowerCase())) {
        await GallerySaver.saveImage(file.path, toDcim: true);
      } else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext.toLowerCase())) {
        await GallerySaver.saveVideo(file.path, toDcim: true);
      } else {
        // Для других файлов показываем диалог
        await GallerySaver.saveImage(file.path, toDcim: true);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл сохранён в галерею!')),
      );
    } catch (e) {
      print('Ошибка сохранения: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    }
  }

  // Открытие просмотра файла
  void _openFile(FileSystemEntity file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FileViewerPage(file: file),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Семейное хранилище'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _loadFiles,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Файлов нет',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      Text(
                        'Нажмите на кнопку + чтобы загрузить',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    final ext = file.path.split('.').last.toLowerCase();
                    final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
                    
                    return GestureDetector(
                      onTap: () => _openFile(file),
                      onLongPress: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.download),
                                  title: const Text('Скачать в галерею'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _saveFileToDevice(file as File);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.delete, color: Colors.red),
                                  title: const Text('Удалить', style: TextStyle(color: Colors.red)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _deleteFile(file);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: isVideo
                                ? Container(
                                    color: Colors.black,
                                    child: Center(
                                      child: Icon(
                                        Icons.play_circle_filled,
                                        size: 48,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  )
                                : Image.file(
                                    File(file.path),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.broken_image, color: Colors.grey),
                                      );
                                    },
                                  ),
                          ),
                          // Иконка видео поверх
                          if (isVideo)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.videocam,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadFile,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================================
// СТРАНИЦА ПРОСМОТРА ФАЙЛА
// ============================================================
class FileViewerPage extends StatefulWidget {
  final FileSystemEntity file;
  const FileViewerPage({super.key, required this.file});

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  VideoPlayerController? _videoController;
  late String _filePath;
  late String _fileExt;

  @override
  void initState() {
    super.initState();
    _filePath = widget.file.path;
    _fileExt = _filePath.split('.').last.toLowerCase();
    
    if (['mp4', 'mov', 'avi', 'mkv'].contains(_fileExt)) {
      _videoController = VideoPlayerController.file(File(_filePath))
        ..initialize().then((_) {
          setState(() {});
        })
        ..setLooping(true)
        ..play();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _saveFileToDevice() async {
    try {
      final file = File(_filePath);
      if (['jpg', 'jpeg', 'png', 'gif'].contains(_fileExt)) {
        await GallerySaver.saveImage(_filePath, toDcim: true);
      } else if (['mp4', 'mov', 'avi', 'mkv'].contains(_fileExt)) {
        await GallerySaver.saveVideo(_filePath, toDcim: true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл сохранён в галерею!')),
      );
    } catch (e) {
      print('Ошибка сохранения: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(_fileExt);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_filePath.split('/').last),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _saveFileToDevice,
            tooltip: 'Сохранить в галерею',
          ),
        ],
      ),
      body: Center(
        child: isVideo
            ? _videoController != null && _videoController!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                : const Center(child: CircularProgressIndicator())
            : InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(
                  File(_filePath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text('Не удалось открыть файл'),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: isVideo && _videoController != null
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                });
              },
              child: Icon(
                _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}