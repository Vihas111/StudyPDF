import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
  late TextEditingController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _isEditing = true;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note.markdownContent);
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

  void _scrollToAnchor(String? href) {
    if (href == null) return;
    
    String? searchTarget;
    int afterIndex = 0;

    if (href.startsWith('#doc=')) {
      final parts = href.substring(5).split('&page=');
      final docTitle = Uri.decodeComponent(parts[0]);
      
      searchTarget = '## $docTitle';
      if (parts.length > 1) {
        final pageNum = parts[1];
        afterIndex = _controller.text.indexOf(searchTarget);
        if (afterIndex == -1) afterIndex = 0;
        searchTarget = '### Page $pageNum';
      }
    } else if (href.startsWith('#page-')) {
      searchTarget = '## Page ${href.substring(6)}';
    } else {
      return;
    }
    
    final text = _controller.text;
    final index = text.indexOf(searchTarget, afterIndex);
    
    if (index != -1 && _scrollController.hasClients) {
       final fraction = index / text.length;
       final maxScroll = _scrollController.position.maxScrollExtent;
       _scrollController.animateTo(
         maxScroll * fraction,
         duration: const Duration(milliseconds: 300),
         curve: Curves.easeIn,
       );
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
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Edit'), icon: Icon(Icons.edit)),
                    ButtonSegment(value: false, label: Text('Preview'), icon: Icon(Icons.preview)),
                  ],
                  selected: {_isEditing},
                  showSelectedIcon: false,
                  onSelectionChanged: (set) {
                    setState(() {
                      _isEditing = set.first;
                    });
                  },
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
            child: _isEditing
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Start writing your unified notes in markdown...',
                      ),
                      style: const TextStyle(height: 1.5),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Markdown(
                      controller: _scrollController,
                      data: _controller.text,
                      selectable: true,
                      onTapLink: (text, href, title) => _scrollToAnchor(href),
                    ),
                  ),
          )
        ],
      ),
    );
  }
}
