import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:studypdf/core/ai/ocr_service.dart';
import 'package:studypdf/core/theme/design_tokens.dart';
import 'package:studypdf/core/utils/slug.dart';
import 'package:studypdf/features/notes/presentation/markdown_extensions.dart';
import 'package:studypdf/features/notes/presentation/markdown_text_editing_controller.dart';
import 'package:studypdf/features/notes/presentation/markdown_toolbar.dart';
import 'package:studypdf/models/merged_note.dart';
import 'package:studypdf/widgets/hover_surface.dart';

/// A custom MarkdownElementBuilder that assigns a GlobalKey to each heading
/// so we can scroll to it when an anchor link is tapped.
///
/// Slugs are scoped under the most recent h2: an h3's key is
/// `<h2-slug>--<h3-slug>` rather than just its own text slug. This matters
/// for workspace-level merged notes, where multiple documents can each
/// have a "Page 1" h3 heading — without scoping, all of them would
/// collide on the same "page-1" key and only the first would ever be
/// reachable. [WorkspaceController]'s merge-notes generators build their
/// Agenda/Master Agenda links using this exact same scoping (see
/// `_agendaLinkForPage` there) so links always resolve.
class _HeadingBuilder extends MarkdownElementBuilder {
  _HeadingBuilder({required this.keyMap});

  /// Maps slug → GlobalKey of the rendered heading widget.
  final Map<String, GlobalKey> keyMap;

  String? _currentH2Slug;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final text = element.textContent;
    final ownSlug = toSlug(text);
    if (element.tag == 'h1') {
      _currentH2Slug = null;
    } else if (element.tag == 'h2') {
      _currentH2Slug = ownSlug;
    }
    final slug = (element.tag == 'h3' && _currentH2Slug != null)
        ? '$_currentH2Slug--$ownSlug'
        : ownSlug;
    final key = keyMap.putIfAbsent(slug, () => GlobalKey());

    TextStyle style;
    switch (element.tag) {
      case 'h1':
        style = Theme.of(context).textTheme.headlineMedium ?? const TextStyle();
        break;
      case 'h2':
        style = Theme.of(context).textTheme.headlineSmall ?? const TextStyle();
        break;
      case 'h3':
        style = Theme.of(context).textTheme.titleLarge ?? const TextStyle();
        break;
      default:
        style = preferredStyle ?? const TextStyle();
    }

    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(text, style: style.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class MergedNoteEditorPanel extends StatefulWidget {
  const MergedNoteEditorPanel({
    super.key,
    required this.note,
    required this.onSave,
    required this.onRename,
    required this.onTranscribeHandwriting,
    required this.onSaveNoteImage,
  });

  final MergedNote note;
  final ValueChanged<String> onSave;
  final ValueChanged<String> onRename;

  /// Transcribes a photo of handwritten notes into typed text. Throws on
  /// failure (missing API key, network error, etc) — the caller shows the
  /// error to the user.
  final Future<HandwritingTranscription> Function(
    Uint8List imageBytes,
    String mimeType,
  )
  onTranscribeHandwriting;

  /// Saves an image into the library's note-assets folder and returns its
  /// path, for embedding a diagram/drawing alongside transcribed text.
  final Future<String> Function(Uint8List imageBytes, String extension)
  onSaveNoteImage;

  @override
  State<MergedNoteEditorPanel> createState() => _MergedNoteEditorPanelState();
}

class _MergedNoteEditorPanelState extends State<MergedNoteEditorPanel> {
  late MarkdownTextEditingController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _isDirty = false;
  bool _isEditing = false;

  /// Maps heading slug → GlobalKey so that onTapLink can find the widget.
  final Map<String, GlobalKey> _headingKeys = {};

  @override
  void initState() {
    super.initState();
    _controller = MarkdownTextEditingController(text: widget.note.markdownContent);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant MergedNoteEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id) {
      _controller.text = widget.note.markdownContent;
      _isDirty = false;
      _headingKeys.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  void _save() {
    widget.onSave(_controller.text);
    setState(() => _isDirty = false);
  }

  /// Called when any link is tapped in the Markdown preview.
  /// If the href starts with '#', treat it as an anchor and scroll to that heading.
  void _onTapLink(String text, String? href, String title) {
    if (href == null || !href.startsWith('#')) return;
    final slug = href.substring(1); // strip leading '#'
    final key = _headingKeys[slug];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _renameTitle() async {
    final titleController = TextEditingController(text: widget.note.pdfTitle);
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Note'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new title...'),
          onSubmitted: (val) => Navigator.of(context).pop(val),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(titleController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (selected != null && selected.trim().isNotEmpty && selected != widget.note.pdfTitle) {
      widget.onRename(selected.trim());
    }
  }

  static const Map<String, String> _mimeTypesByExtension = {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
  };

  void _insertAtCursor(String snippet) {
    final value = _controller.value;
    final selection = value.selection;
    final text = value.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final next = text.replaceRange(start, end, snippet);
    final cursor = start + snippet.length;
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cursor),
    );
    setState(() {
      _isDirty = true;
    });
  }

  Future<void> _importHandwrittenNote() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }
    final extension = path.split('.').last.toLowerCase();
    final mimeType = _mimeTypesByExtension[extension] ?? 'image/png';
    final bytes = await File(path).readAsBytes();

    if (!mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.md),
            Text('Transcribing handwritten note...'),
          ],
        ),
      ),
    );

    HandwritingTranscription transcription;
    try {
      transcription = await widget.onTranscribeHandwriting(bytes, mimeType);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Handwriting import failed: $e')),
      );
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }

    if (!mounted) {
      return;
    }

    final reviewResult = await showDialog<_HandwritingReviewResult>(
      context: context,
      builder: (context) => _HandwritingReviewDialog(
        imageBytes: bytes,
        initialText: transcription.text,
        suggestKeepImage: transcription.hasNonTextContent,
      ),
    );
    if (reviewResult == null) {
      return;
    }

    final buffer = StringBuffer();
    if (reviewResult.text.trim().isNotEmpty) {
      buffer.writeln(reviewResult.text.trim());
    }
    if (reviewResult.keepImage) {
      try {
        final savedPath = await widget.onSaveNoteImage(bytes, extension);
        final uriPath = savedPath.replaceAll('\\', '/');
        buffer.writeln('\n![handwritten note](file://$uriPath)');
      } catch (e) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save image: $e')),
        );
      }
    }

    if (buffer.isNotEmpty) {
      _insertAtCursor('\n${buffer.toString()}\n');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Single shared instance across h1/h2/h3 so its h2-scoping state
    // persists through one full render pass (see class doc).
    final headingBuilder = _HeadingBuilder(keyMap: _headingKeys);
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.sticky_note_2, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.note.pdfTitle,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Tooltip(
                        message: 'Rename Note',
                        child: HoverSurface(
                          onTap: _renameTitle,
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          child: const Icon(Icons.edit, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Tooltip(
                  message: 'Import handwritten note',
                  child: HoverSurface(
                    onTap: _importHandwrittenNote,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: const Icon(Icons.document_scanner_outlined, size: 20),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, icon: Icon(Icons.preview), label: Text('Preview')),
                    ButtonSegment(value: true, icon: Icon(Icons.edit), label: Text('Edit')),
                  ],
                  selected: {_isEditing},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _isEditing = newSelection.first;
                      // Clear heading keys so they get re-registered fresh on next preview build
                      if (!_isEditing) _headingKeys.clear();
                    });
                  },
                  showSelectedIcon: false,
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: _isDirty ? _save : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isEditing
                ? Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: MarkdownToolbar(
                          controller: _controller,
                          focusNode: FocusNode(),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          child: TextField(
                            controller: _controller,
                            scrollController: _scrollController,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Start writing your unified notes in markdown...',
                            ),
                            style: const TextStyle(height: 1.5),
                          ),
                        ),
                      ),
                    ],
                  )
                : Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      // MarkdownBody (not Markdown) is required here: the
                      // Markdown widget renders into a virtualizing
                      // ListView, so headings far down a long merged note
                      // are never built and their GlobalKeys never get a
                      // context — Scrollable.ensureVisible then silently
                      // does nothing, which is why tapping a Table of
                      // Contents / Agenda link wasn't scrolling anywhere.
                      // MarkdownBody renders a plain, fully-built Column
                      // instead, so every heading's key is always valid.
                      child: MarkdownBody(
                        data: _controller.text.isEmpty
                            ? '*No content yet. Switch to Edit to write something!*'
                            : _controller.text,
                        extensionSet: md.ExtensionSet.gitHubWeb,
                        onTapLink: _onTapLink,
                        // One shared _HeadingBuilder instance across
                        // h1/h2/h3: its h2-scoping state must persist
                        // across tags within a single render pass (see
                        // class doc on _HeadingBuilder).
                        builders: {
                          'u': UnderlineBuilder(),
                          'h1': headingBuilder,
                          'h2': headingBuilder,
                          'h3': headingBuilder,
                        },
                        inlineSyntaxes: [UnderlineSyntax()],
                        styleSheet: MarkdownStyleSheet(
                          p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                          code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                          codeblockDecoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
          )
        ],
      ),
    );
  }
}

class _HandwritingReviewResult {
  const _HandwritingReviewResult({required this.text, required this.keepImage});

  final String text;
  final bool keepImage;
}

/// Lets the user review/edit the OCR'd text before it's inserted into the
/// note, and choose whether to keep the original photo attached (for
/// diagrams/drawings the model can't transcribe as text). Never silently
/// trusts the transcription — this confirm step is mandatory.
class _HandwritingReviewDialog extends StatefulWidget {
  const _HandwritingReviewDialog({
    required this.imageBytes,
    required this.initialText,
    required this.suggestKeepImage,
  });

  final Uint8List imageBytes;
  final String initialText;
  final bool suggestKeepImage;

  @override
  State<_HandwritingReviewDialog> createState() =>
      _HandwritingReviewDialogState();
}

class _HandwritingReviewDialogState extends State<_HandwritingReviewDialog> {
  late final TextEditingController _textController;
  late bool _keepImage;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _keepImage = widget.suggestKeepImage;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Review transcription'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: Image.memory(
                widget.imageBytes,
                height: 140,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Edit the transcribed text before inserting it — OCR can make mistakes.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _textController,
              maxLines: 8,
              minLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Transcribed text...',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Also keep the original photo'),
              subtitle: const Text(
                'Recommended if the page has a diagram or drawing.',
              ),
              value: _keepImage,
              onChanged: (value) => setState(() => _keepImage = value ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _HandwritingReviewResult(
              text: _textController.text,
              keepImage: _keepImage,
            ),
          ),
          child: const Text('Insert'),
        ),
      ],
    );
  }
}
