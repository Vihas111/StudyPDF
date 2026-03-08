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
      if (type == 'md') {
        await file.writeAsString(note.markdownContent);
      } else if (type == 'pdf') {
        final pdf = PdfDocument();
        PdfPage page = pdf.pages.add();
        
        final PdfFont h1Font = PdfStandardFont(PdfFontFamily.helvetica, 22, style: PdfFontStyle.bold);
        final PdfFont h2Font = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
        final PdfFont h3Font = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
        final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
        
        final format = PdfLayoutFormat(layoutType: PdfLayoutType.paginate);
        final stringFormat = PdfStringFormat(wordWrap: PdfWordWrapType.word);
        
        double currentY = 0;
        final lines = note.markdownContent.split('\n');
        
        for (var line in lines) {
          if (line.trim().isEmpty) {
            currentY += 15;
            if (currentY > page.getClientSize().height - 20) {
              page = pdf.pages.add();
              currentY = 0;
            }
            continue;
          }
          
          PdfFont font = bodyFont;
          String text = line;
          
          if (text.startsWith('# ')) {
             font = h1Font;
             text = text.substring(2);
          } else if (text.startsWith('## ')) {
             font = h2Font;
             text = text.substring(3);
          } else if (text.startsWith('### ')) {
             font = h3Font;
             text = text.substring(4);
          }
          
          text = text.replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (m) => m.group(1)!);
          text = text.replaceAll('**', '');
          text = text.replaceAll('*', '');
          text = text.replaceAll(RegExp(r'^#+\s'), ''); // Fallback for smaller headers

          // Ensure string is not empty after stripping just in case
          if (text.trim().isEmpty) continue;

          // Replace unsupported unicode chars with spaces to prevent font exceptions
          text = text.replaceAll(RegExp(r'[^\x00-\x7F]'), ' ');

          // Prevent bounds crash on page end calculation
          if (currentY > page.getClientSize().height - 20) {
            page = pdf.pages.add();
            currentY = 0;
          }
          
          // Define next page boundaries perfectly so paginate never infinite loops 
          format.paginateBounds = Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height);

          final element = PdfTextElement(text: text, font: font, format: stringFormat);
          final layoutResult = element.draw(
            page: page,
            bounds: Rect.fromLTWH(0, currentY, page.getClientSize().width, 0),
            format: format,
          );
          
          if (layoutResult != null) {
            page = layoutResult.page;
            currentY = layoutResult.bounds.bottom + 5;
          }
        }
        
        final bytes = await pdf.save();
        await file.writeAsBytes(bytes);
        pdf.dispose();
      }
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
          child: Row(
            children: [
              Text(
                'Merged Notes',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
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
        return Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => widget.onOpenNote(note),
            onSecondaryTapDown: (details) => _showNoteMenu(note, details.globalPosition),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
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
        return GestureDetector(
          onSecondaryTapDown: (details) => _showNoteMenu(note, details.globalPosition),
          child: ListTile(
            leading: const Icon(Icons.sticky_note_2, color: Colors.blueAccent),
            title: Text(
              note.pdfTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Updated: ${formatter.format(note.updatedAt)}'),
            trailing: Builder(
              builder: (buttonContext) => IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  final RenderBox box = buttonContext.findRenderObject() as RenderBox;
                  final offset = box.localToGlobal(Offset.zero);
                  _showNoteMenu(note, offset + Offset(box.size.width / 2, box.size.height / 2)); 
                },
              ),
            ),
            onTap: () => widget.onOpenNote(note),
          ),
        );
      },
    );
  }
}
