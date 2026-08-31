import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Stores images embedded in notes (e.g. diagrams kept from an imported
/// handwritten-note photo) inside the library root, mirroring
/// [FileLibraryService]'s copy-into-library pattern so note assets travel
/// with the library rather than living in a separate app-data folder.
class NoteAssetsStore {
  static const String assetsFolderName = '_note_assets';

  Future<String> saveImage({
    required String libraryRoot,
    required Uint8List bytes,
    required String extension,
  }) async {
    final dir = Directory(p.join(libraryRoot, assetsFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final sanitizedExt = extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}.${sanitizedExt.isEmpty ? 'png' : sanitizedExt}';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
