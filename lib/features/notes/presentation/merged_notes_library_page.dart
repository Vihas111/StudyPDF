import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:studypdf/core/storage/merged_notes_store.dart';
import 'package:studypdf/models/merged_note.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class MergedNotesLibraryPage extends StatefulWidget {
  const MergedNotesLibraryPage({
    super.key,
    required this.store,
    required this.onOpenNote,
  });

  final MergedNotesStore store;
  final ValueChanged<MergedNote> onOpenNote;

  @override
  State<MergedNotesLibraryPage> createState() => _MergedNotesLibraryPageState();
}

class _MergedNotesLibraryPageState extends State<MergedNotesLibraryPage> {
  List<MergedNote> _notes = [];
  bool _isGridView = true;
  bool _selectionMode = false;
  final Set<String> _selectedNoteIds = <String>{};

  @override
  void initState() {
    super.initState();
    _refreshNotes();
  }

  @override
  void didUpdateWidget(covariant MergedNotesLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshNotes();
  }

  void _refreshNotes() {
    setState(() {
      _notes = widget.store.getAllNotes();
    });
  }

  /// Draws a markdown image reference (a `file://` path, as produced by the
  /// "Insert Image" toolbar button and the handwritten-note importer) into
  /// the PDF, scaled to fit the page width. Returns null (rather than
  /// throwing) if the path can't be resolved or the image can't be decoded,
  /// so the caller can fall back to rendering the line as plain text.
  Future<_ImageDrawResult?> _tryDrawImage({
    required PdfDocument pdf,
    required PdfPage page,
    required String imagePath,
    required double currentY,
  }) async {
    try {
      var path = imagePath.trim();
      if (path.startsWith('file://')) {
        path = path.substring('file://'.length);
      }
      // A leading slash before a Windows drive letter (file:///C:/...)
      // needs stripping too.
      if (path.startsWith('/') && path.length > 2 && path[2] == ':') {
        path = path.substring(1);
      }
      final imageFile = File(path);
      if (!await imageFile.exists()) {
        return null;
      }
      final bytes = await imageFile.readAsBytes();
      final bitmap = PdfBitmap(bytes);

      final pageWidth = page.getClientSize().width;
      final maxHeight = 260.0;
      var drawWidth = bitmap.width.toDouble();
      var drawHeight = bitmap.height.toDouble();
      final widthScale = pageWidth / drawWidth;
      drawWidth *= widthScale;
      drawHeight *= widthScale;
      if (drawHeight > maxHeight) {
        final heightScale = maxHeight / drawHeight;
        drawHeight *= heightScale;
        drawWidth *= heightScale;
      }

      var targetPage = page;
      var y = currentY;
      if (y + drawHeight > targetPage.getClientSize().height - 20) {
        targetPage = pdf.pages.add();
        y = 0;
      }

      bitmap.draw(
        page: targetPage,
        bounds: Rect.fromLTWH(0, y, drawWidth, drawHeight),
      );
      return _ImageDrawResult(page: targetPage, bottom: y + drawHeight);
    } catch (_) {
      return null;
    }
  }

  Future<void> _exportNote(MergedNote note, String type) async {
    final title = note.pdfTitle.replaceAll(RegExp(r'[^a-zA-Z0-9.\-_ ()]'), '_');
    final String? result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Note',
      fileName: '$title.$type',
      type: FileType.custom,
      allowedExtensions: [type],
    );

    if (result == null) return;

    try {
      final file = File(result);
      await _writeNoteExport(file: file, note: note, type: type);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note exported to ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export note: $e')),
      );
    }
  }

  Future<void> _exportSelectedNotes(String type) async {
    final notesToExport = _notes
        .where((n) => _selectedNoteIds.contains(n.id))
        .toList(growable: false);
    if (notesToExport.isEmpty) {
      return;
    }

    final folder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose export folder',
    );
    if (folder == null) return;

    var successCount = 0;
    final errors = <String>[];
    for (final note in notesToExport) {
      try {
        final safeName = note.pdfTitle.replaceAll(RegExp(r'[^a-zA-Z0-9.\-_ ()]'), '_');
        final path = _resolveNonCollidingPath('$folder${Platform.pathSeparator}$safeName.$type');
        await _writeNoteExport(file: File(path), note: note, type: type);
        successCount++;
      } catch (e) {
        errors.add('${note.pdfTitle}: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedNoteIds.clear();
    });
    final message = errors.isEmpty
        ? 'Exported $successCount note(s) to $folder'
        : 'Exported $successCount note(s), ${errors.length} failed (${errors.first})';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _resolveNonCollidingPath(String candidatePath) {
    if (!File(candidatePath).existsSync()) {
      return candidatePath;
    }
    final dotIndex = candidatePath.lastIndexOf('.');
    final base = dotIndex == -1 ? candidatePath : candidatePath.substring(0, dotIndex);
    final ext = dotIndex == -1 ? '' : candidatePath.substring(dotIndex);
    var index = 1;
    while (true) {
      final next = '$base ($index)$ext';
      if (!File(next).existsSync()) {
        return next;
      }
      index++;
    }
  }

  /// Writes [note] to [file] as either raw markdown or a rendered PDF.
  /// Shared by single-note export and the multi-select batch export.
  Future<void> _writeNoteExport({
    required File file,
    required MergedNote note,
    required String type,
  }) async {
    if (type == 'md') {
      await file.writeAsString(note.markdownContent);
      return;
    }
    if (type != 'pdf') {
      return;
    }

    final pdf = PdfDocument();
    PdfPage page = pdf.pages.add();

    final PdfFont h1Font = PdfStandardFont(PdfFontFamily.helvetica, 22, style: PdfFontStyle.bold);
    final PdfFont h2Font = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont h3Font = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final PdfFont boldBodyFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final PdfFont italicBodyFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.italic);
    final PdfFont codeFont = PdfStandardFont(PdfFontFamily.courier, 11);

    final format = PdfLayoutFormat(layoutType: PdfLayoutType.paginate);
    final stringFormat = PdfStringFormat(wordWrap: PdfWordWrapType.word);
    final imagePathPattern = RegExp(r'^!\[[^\]]*\]\(([^)]+)\)$');
    final bulletPattern = RegExp(r'^[-*]\s+(.*)$');
    final numberedPattern = RegExp(r'^(\d+)\.\s+(.*)$');
    const bulletIndent = 20.0;
    final codeBlockBg = PdfColor(240, 240, 240);

    double currentY = 0;
    var inCodeBlock = false;
    final lines = note.markdownContent.split('\n');

    for (var line in lines) {
      final trimmedForFence = line.trim();
      if (trimmedForFence.startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        continue;
      }

      if (line.trim().isEmpty && !inCodeBlock) {
        currentY += 15;
        if (currentY > page.getClientSize().height - 20) {
          page = pdf.pages.add();
          currentY = 0;
        }
        continue;
      }

      // Embedded images (from the "Insert Image" toolbar or handwritten
      // note import) get drawn as actual images instead of being
      // silently dropped or rendered as raw markdown syntax.
      if (!inCodeBlock) {
        final imageMatch = imagePathPattern.firstMatch(line.trim());
        if (imageMatch != null) {
          final drawn = await _tryDrawImage(
            pdf: pdf,
            page: page,
            imagePath: imageMatch.group(1)!,
            currentY: currentY,
          );
          if (drawn != null) {
            page = drawn.page;
            currentY = drawn.bottom + 8;
            continue;
          }
          // Fall through to render as text (e.g. a broken/missing path)
          // rather than silently dropping the line.
        }
      }

      PdfFont font = bodyFont;
      String text = line;
      double indent = 0;

      if (inCodeBlock) {
        font = codeFont;
        // Preserve leading whitespace (indentation) in code; only trim
        // the trailing newline artifacts.
        text = line.replaceAll(RegExp(r'[\r\n]+$'), '');
        if (text.trim().isEmpty) {
          text = ' ';
        }
      } else if (text.startsWith('# ')) {
         font = h1Font;
         text = text.substring(2);
      } else if (text.startsWith('## ')) {
         font = h2Font;
         text = text.substring(3);
      } else if (text.startsWith('### ')) {
         font = h3Font;
         text = text.substring(4);
      } else {
        final trimmed = text.trim();
        final bulletMatch = bulletPattern.firstMatch(trimmed);
        final numberedMatch = numberedPattern.firstMatch(trimmed);
        if (bulletMatch != null) {
          text = '•  ${bulletMatch.group(1)}';
          indent = bulletIndent;
        } else if (numberedMatch != null) {
          text = '${numberedMatch.group(1)}.  ${numberedMatch.group(2)}';
          indent = bulletIndent;
        } else if (trimmed.startsWith('**') && trimmed.endsWith('**') && trimmed.length > 4) {
          font = boldBodyFont;
        } else if (trimmed.startsWith('*') &&
            trimmed.endsWith('*') &&
            !trimmed.startsWith('**') &&
            trimmed.length > 2) {
          font = italicBodyFont;
        }
      }

      text = text.replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (m) => m.group(1)!);
      text = text.replaceAll('**', '');
      text = text.replaceAll('*', '');
      if (!inCodeBlock) {
        text = text.replaceAll(RegExp(r'^#+\s'), ''); // Fallback for smaller headers
      }

      // Ensure string is not empty after stripping just in case
      if (text.trim().isEmpty && !inCodeBlock) continue;

      // Replace unsupported unicode chars with spaces to prevent font exceptions
      text = text.replaceAll(RegExp(r'[^\x00-\x7F]'), ' ');

      // Prevent bounds crash on page end calculation
      if (currentY > page.getClientSize().height - 20) {
        page = pdf.pages.add();
        currentY = 0;
      }

      // Define next page boundaries perfectly so paginate never infinite loops
      format.paginateBounds = Rect.fromLTWH(indent, 0, page.getClientSize().width - indent, page.getClientSize().height);

      if (inCodeBlock) {
        // Shade the code line's background before drawing the monospace
        // text on top, so code blocks read distinctly from body text.
        final lineHeight = font.height + 2;
        page.graphics.drawRectangle(
          brush: PdfSolidBrush(codeBlockBg),
          bounds: Rect.fromLTWH(0, currentY, page.getClientSize().width, lineHeight),
        );
      }

      final element = PdfTextElement(text: text, font: font, format: stringFormat);
      final layoutResult = element.draw(
        page: page,
        bounds: Rect.fromLTWH(indent, currentY, page.getClientSize().width - indent, 0),
        format: format,
      );

      if (layoutResult != null) {
        page = layoutResult.page;
        currentY = layoutResult.bounds.bottom + (inCodeBlock ? 2 : 5);
      }
    }

    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);
    pdf.dispose();
  }

  Future<void> _showNoteMenu(MergedNote note, Offset globalPosition) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: const [
        PopupMenuItem<String>(value: 'edit', child: Text('Edit Note')),
        PopupMenuItem<String>(value: 'export', child: Text('Export Note')),
        PopupMenuItem<String>(value: 'delete', child: Text('Delete Note')),
      ],
    );

    if (!mounted || action == null) return;

    if (action == 'edit') {
      widget.onOpenNote(note);
    } else if (action == 'export') {
      final exportType = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Note'),
          content: Text('How would you like to export "${note.pdfTitle}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('md'),
              child: const Text('Markdown (.md)'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('pdf'),
              child: const Text('PDF Document (.pdf)'),
            ),
          ],
        ),
      );
      if (exportType != null) {
        await _exportNote(note, exportType);
      }
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Note?'),
          content: Text('Are you sure you want to delete notes for "${note.pdfTitle}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await widget.store.deleteNote(note.id);
        _refreshNotes();
      }
    }
  }

  Future<void> _showBatchExportDialog() async {
    final exportType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Selected Notes'),
        content: Text(
          'Export ${_selectedNoteIds.length} note(s) — choose a format:',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('md'),
            child: const Text('Markdown (.md)'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('pdf'),
            child: const Text('PDF Document (.pdf)'),
          ),
        ],
      ),
    );
    if (exportType != null) {
      await _exportSelectedNotes(exportType);
    }
  }

  void _toggleSelected(String noteId) {
    setState(() {
      if (_selectedNoteIds.contains(noteId)) {
        _selectedNoteIds.remove(noteId);
      } else {
        _selectedNoteIds.add(noteId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_notes.isEmpty) {
      return const Center(child: Text('No merged notes found. Open a PDF and select "Merge Notes" from the tab menu.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _selectionMode
              ? Row(
                  children: [
                    Text(
                      '${_selectedNoteIds.length} selected',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        _selectionMode = false;
                        _selectedNoteIds.clear();
                      }),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _selectedNoteIds.isEmpty
                          ? null
                          : () => _showBatchExportDialog(),
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Export Selected'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Text(
                      'Merged Notes',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() => _selectionMode = true),
                      icon: const Icon(Icons.checklist),
                      label: const Text('Select'),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: true,
                          icon: Icon(Icons.grid_view),
                          label: Text('Grid'),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          icon: Icon(Icons.view_list),
                          label: Text('List'),
                        ),
                      ],
                      selected: {_isGridView},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _isGridView = selection.first;
                        });
                      },
                    ),
                  ],
                ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isGridView ? _buildGridView() : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        final formatter = DateFormat.yMMMd().add_jm();
        final isSelected = _selectedNoteIds.contains(note.id);
        return Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _selectionMode
                ? () => _toggleSelected(note.id)
                : () => widget.onOpenNote(note),
            onSecondaryTapDown: (details) => _showNoteMenu(note, details.globalPosition),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_selectionMode)
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelected(note.id),
                        )
                      else
                        const Icon(Icons.sticky_note_2, size: 20, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note.pdfTitle,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_selectionMode)
                        Builder(
                          builder: (buttonContext) => IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () {
                              final RenderBox box = buttonContext.findRenderObject() as RenderBox;
                              final offset = box.localToGlobal(Offset.zero);
                              _showNoteMenu(note, offset + Offset(box.size.width / 2, box.size.height / 2));
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Updated: ${formatter.format(note.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: ClipRect(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: MarkdownBody(
                          data: note.markdownContent,
                          styleSheet: MarkdownStyleSheet(
                            p: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        final formatter = DateFormat.yMMMd().add_jm();
        final isSelected = _selectedNoteIds.contains(note.id);
        return GestureDetector(
          onSecondaryTapDown: (details) => _showNoteMenu(note, details.globalPosition),
          child: ListTile(
            leading: _selectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelected(note.id),
                  )
                : const Icon(Icons.sticky_note_2, color: Colors.blueAccent),
            title: Text(
              note.pdfTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Updated: ${formatter.format(note.updatedAt)}'),
            trailing: _selectionMode
                ? null
                : Builder(
                    builder: (buttonContext) => IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {
                        final RenderBox box = buttonContext.findRenderObject() as RenderBox;
                        final offset = box.localToGlobal(Offset.zero);
                        _showNoteMenu(note, offset + Offset(box.size.width / 2, box.size.height / 2));
                      },
                    ),
                  ),
            onTap: _selectionMode
                ? () => _toggleSelected(note.id)
                : () => widget.onOpenNote(note),
          ),
        );
      },
    );
  }
}

class _ImageDrawResult {
  const _ImageDrawResult({required this.page, required this.bottom});

  final PdfPage page;
  final double bottom;
}
