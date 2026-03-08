import 'package:flutter/material.dart';
import 'package:studypdf/features/notes/presentation/markdown_text_editing_controller.dart';
import 'package:studypdf/features/notes/presentation/markdown_toolbar.dart';
import 'package:studypdf/models/merged_note.dart';

class MergedNoteEditorPanel extends StatefulWidget {
  const MergedNoteEditorPanel({
    super.key,
    required this.note,
    required this.onSave,
    required this.onRename,
  });

  final MergedNote note;
  final ValueChanged<String> onSave;
  final ValueChanged<String> onRename;

  @override
  State<MergedNoteEditorPanel> createState() => _MergedNoteEditorPanelState();
}

class _MergedNoteEditorPanelState extends State<MergedNoteEditorPanel> {
  late MarkdownTextEditingController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _isDirty = false;

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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.sticky_note_2, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.note.pdfTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16),
                        onPressed: _renameTitle,
                        tooltip: 'Rename Note',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _isDirty ? _save : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: MarkdownToolbar(
                    controller: _controller,
                    focusNode: FocusNode(), // Simplified for brevity; usually managed in state
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            ),
          )
        ],
      ),
    );
  }
}
