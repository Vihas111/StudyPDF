import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:studypdf/models/annotation.dart';
import 'package:studypdf/features/notes/presentation/markdown_extensions.dart';
import 'package:studypdf/features/notes/presentation/markdown_text_editing_controller.dart';
import 'package:studypdf/features/notes/presentation/markdown_toolbar.dart';

class PageNotesPanel extends StatefulWidget {
  const PageNotesPanel({
    super.key,
    required this.pageNumber,
    required this.annotations,
    required this.onSave,
  });

  final int pageNumber;
  final List<Annotation> annotations;
  final ValueChanged<String> onSave;

  @override
  State<PageNotesPanel> createState() => _PageNotesPanelState();
}

class _PageNotesPanelState extends State<PageNotesPanel> {
  final MarkdownTextEditingController _controller = MarkdownTextEditingController();
  final FocusNode _editorFocusNode = FocusNode();
  bool _dirty = false;

  Annotation? get _latestSavedNote {
    if (widget.annotations.isEmpty) {
      return null;
    }
    final sorted = List<Annotation>.from(widget.annotations)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.first;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedIntoEditor(force: true);
    _controller.addListener(() {
      _dirty = true;
    });
  }

  @override
  void didUpdateWidget(covariant PageNotesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pageChanged = oldWidget.pageNumber != widget.pageNumber;
    final notesChanged = oldWidget.annotations != widget.annotations;
    if (pageChanged) {
      _loadSavedIntoEditor(force: true);
      return;
    }
    if (notesChanged && !_dirty) {
      _loadSavedIntoEditor(force: true);
    }
  }

  @override
  void dispose() {
    _editorFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _loadSavedIntoEditor({required bool force}) {
    if (!force && _dirty) {
      return;
    }
    final saved = _latestSavedNote;
    _controller.value = TextEditingValue(
      text: saved?.content ?? '',
      selection: TextSelection.collapsed(offset: (saved?.content ?? '').length),
    );
    _dirty = false;
  }

  Future<void> _showNoteContextMenu(
    BuildContext context,
    TapDownDetails details,
    Annotation note,
  ) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: const [
        PopupMenuItem<String>(value: 'edit', child: Text('Edit note')),
        PopupMenuItem<String>(value: 'copy', child: Text('Copy note')),
      ],
    );
    if (!mounted || result == null) {
      return;
    }
    if (result == 'edit') {
      _controller.value = TextEditingValue(
        text: note.content,
        selection: TextSelection.collapsed(offset: note.content.length),
      );
      _dirty = true;
      _editorFocusNode.requestFocus();
      setState(() {});
      return;
    }
    if (result == 'copy') {
      await Clipboard.setData(ClipboardData(text: note.content));
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note copied to clipboard')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasFiniteHeight = constraints.maxHeight.isFinite;

          // ── Header row ──────────────────────────────────────────────────
          final header = Row(
            children: [
              Text(
                'Page ${widget.pageNumber} Notes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          );

          // ── Toolbar ───────────────────────────────────────────────────────
          final toolbar = Column(children: [
            const SizedBox(height: 8),
            MarkdownToolbar(controller: _controller, focusNode: _editorFocusNode),
          ]);

          // ── Editor area ───────────────────────────────────────────────────
          final editorArea = TextField(
            controller: _controller,
            focusNode: _editorFocusNode,
            expands: hasFiniteHeight,
            minLines: hasFiniteHeight ? null : 12,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText:
                  'Write markdown notes here. Example:\n## Key ideas\n- point 1\n```python\nprint("hello")\n```',
              border: OutlineInputBorder(),
            ),
          );

          // ── Save button ───────────────────────────────────────────────────
          final saveButton = Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                final value = _controller.text.trim();
                if (value.isEmpty) return;
                widget.onSave(value);
                _dirty = false;
                setState(() {});
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save note'),
            ),
          );

          // ── Saved note preview ───────────────────────────────────────────
          final savedNoteSection = _latestSavedNote == null
              ? const Text('No saved note for this page yet.')
              : GestureDetector(
                  onSecondaryTapDown: (details) =>
                      _showNoteContextMenu(context, details, _latestSavedNote!),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Saved note', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 6),
                        MarkdownBody(
                          data: _latestSavedNote!.content,
                          selectable: true,
                          extensionSet: md.ExtensionSet.gitHubWeb,
                          inlineSyntaxes: [UnderlineSyntax()],
                          builders: {'u': UnderlineBuilder()},
                          imageBuilder: (uri, title, alt) => Image.file(File(uri.path)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Updated ${_latestSavedNote!.createdAt.toLocal().toIso8601String()}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );

          // ── Layout ────────────────────────────────────────────────────────
          if (hasFiniteHeight) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: constraints.maxWidth - 24,
                height: constraints.maxHeight - 24,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    toolbar,
                    const SizedBox(height: 10),
                    Expanded(child: editorArea),
                    const SizedBox(height: 10),
                    saveButton,
                    const Divider(height: 22),
                    Flexible(
                      fit: FlexFit.loose,
                      child: SingleChildScrollView(child: savedNoteSection),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    toolbar,
                    const SizedBox(height: 10),
                    editorArea,
                    const SizedBox(height: 10),
                    saveButton,
                    const Divider(height: 22),
                    savedNoteSection,
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
