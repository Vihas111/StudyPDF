import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:studypdf/models/library_folder.dart';
import 'package:studypdf/models/pdf_document.dart';

class FileLibraryService {
  Directory? _rootDirectory;

  Future<void> setRootPath(String rootPath) async {
    final trimmed = rootPath.trim();
    if (trimmed.isEmpty) {
      _rootDirectory = null;
      return;
    }
    final dir = Directory(trimmed);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _rootDirectory = dir;
  }

  Future<Directory> ensureRoot() async {
    if (_rootDirectory != null) {
      return _rootDirectory!;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final libraryRoot = Directory(p.join(appDir.path, 'studypdf_library'));
    if (!await libraryRoot.exists()) {
      await libraryRoot.create(recursive: true);
    }
    _rootDirectory = libraryRoot;
    return libraryRoot;
  }

  Future<String> getRootPath() async {
    return (await ensureRoot()).path;
  }

  Future<List<LibraryFolder>> getFolders() async {
    final root = await ensureRoot();
    final folders = <LibraryFolder>[
      const LibraryFolder(path: '', name: 'All Files'),
    ];

    final nestedDirectories =
        root
            .listSync(recursive: true)
            .whereType<Directory>()
            .where((dir) => p.basename(dir.path) != '.')
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final dir in nestedDirectories) {
      final relativePath = p.relative(dir.path, from: root.path);
      folders.add(
        LibraryFolder(path: relativePath, name: p.basename(dir.path)),
      );
    }
    return folders;
  }

  Future<void> createFolder({
    required String name,
    String? parentRelativePath,
  }) async {
    final sanitized = name.trim();
    if (sanitized.isEmpty) {
      return;
    }

    final root = await ensureRoot();
    final parent = (parentRelativePath == null || parentRelativePath.isEmpty)
        ? root.path
        : p.join(root.path, parentRelativePath);
    final dir = Directory(p.join(parent, sanitized));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<PdfDocument?> importPdf({
    required String sourceFilePath,
    String? targetFolderRelativePath,
  }) async {
    final source = File(sourceFilePath);
    if (!await source.exists()) {
      return null;
    }

    final root = await ensureRoot();
    final targetFolderPath =
        (targetFolderRelativePath == null || targetFolderRelativePath.isEmpty)
        ? root.path
        : p.join(root.path, targetFolderRelativePath);
    final targetFolder = Directory(targetFolderPath);
    if (!await targetFolder.exists()) {
      await targetFolder.create(recursive: true);
    }

    final extension = p.extension(source.path).toLowerCase();
    if (extension != '.pdf') {
      return null;
    }

    final targetPath = _resolveNonCollidingPath(
      p.join(targetFolder.path, p.basename(source.path)),
    );

    final copied = await source.copy(targetPath);
    return PdfDocument(
      id: copied.path,
      path: copied.path,
      title: p.basename(copied.path),
      folderPath: p.relative(p.dirname(copied.path), from: root.path),
      lastOpened: DateTime.now(),
      progress: 0,
    );
  }

  Future<List<PdfDocument>> importPdfs({
    required List<String> sourceFilePaths,
    String? targetFolderRelativePath,
  }) async {
    final imported = <PdfDocument>[];
    for (final path in sourceFilePaths) {
      final doc = await importPdf(
        sourceFilePath: path,
        targetFolderRelativePath: targetFolderRelativePath,
      );
      if (doc != null) {
        imported.add(doc);
      }
    }
    return imported;
  }

  Future<List<PdfDocument>> getDocuments({String? folderRelativePath}) async {
    final root = await ensureRoot();
    final files = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.pdf')
        .toList();

    final docs = files.map((file) {
      final fileDir = p.dirname(file.path);
      final folderPath = p.relative(fileDir, from: root.path);
      return PdfDocument(
        id: file.path,
        path: file.path,
        title: p.basename(file.path),
        folderPath: folderPath == '.' ? '' : folderPath,
        lastOpened: file.statSync().modified,
        progress: 0,
      );
    }).toList();

    docs.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    if (folderRelativePath == null || folderRelativePath.isEmpty) {
      return docs;
    }

    return docs.where((doc) => doc.folderPath == folderRelativePath).toList();
  }

  Future<void> deleteDocument(String documentPath) async {
    final file = File(documentPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteFolder(String folderRelativePath) async {
    if (folderRelativePath.isEmpty) {
      return;
    }
    final root = await ensureRoot();
    final normalized = folderRelativePath.replaceAll('/', p.separator);
    final folder = Directory(p.normalize(p.join(root.path, normalized)));
    if (await folder.exists()) {
      await _deleteDirectoryRobust(folder);
    }
  }

  Future<void> _deleteDirectoryRobust(Directory folder) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        if (await folder.exists()) {
          await folder.delete(recursive: true);
        }
      } catch (_) {}

      if (!await folder.exists()) {
        return;
      }

      try {
        final result = await Process.run('cmd', [
          '/c',
          'rmdir',
          '/s',
          '/q',
          folder.path,
        ]);
        if (result.exitCode == 0 && !await folder.exists()) {
          return;
        }
      } catch (_) {}

      try {
        final entities = folder.listSync(recursive: true)
          ..sort((a, b) => b.path.length.compareTo(a.path.length));
        for (final entity in entities) {
          if (entity is File && entity.existsSync()) {
            entity.deleteSync();
          } else if (entity is Directory && entity.existsSync()) {
            entity.deleteSync();
          }
        }
        if (folder.existsSync()) {
          folder.deleteSync();
        }
      } catch (_) {}

      if (!await folder.exists()) {
        return;
      }

      await Future<void>.delayed(Duration(milliseconds: 120 * (attempt + 1)));
    }
  }

  String _resolveNonCollidingPath(String candidatePath) {
    if (!File(candidatePath).existsSync()) {
      return candidatePath;
    }

    final dir = p.dirname(candidatePath);
    final name = p.basenameWithoutExtension(candidatePath);
    final ext = p.extension(candidatePath);

    var index = 1;
    while (true) {
      final next = p.join(dir, '$name ($index)$ext');
      if (!File(next).existsSync()) {
        return next;
      }
      index++;
    }
  }
}
