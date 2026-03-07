import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studypdf/models/annotation.dart';

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
  final TextEditingController _controller = TextEditingController();
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

  void _insertWrap(String left, String right) {
    final value = _controller.value;
    final selection = value.selection;
    if (!selection.isValid) {
      return;
    }
    final text = value.text;
    final start = selection.start;
    final end = selection.end;
    final selected = text.substring(start, end);
    final next = text.replaceRange(start, end, '$left$selected$right');
    final cursor = start + left.length + selected.length + right.length;
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _editorFocusNode.requestFocus();
  }

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
    _editorFocusNode.requestFocus();
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Page ${widget.pageNumber} Notes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                const Spacer(),

                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ToolbarChip(label: 'Bold', onTap: () => _insertWrap('**', '**')),
                        const SizedBox(width: 6),
                        _ToolbarChip(
                          label: 'Code',
                          onTap: () => _insertAtCursor('\n```text\ncode here\n```\n'),
                        ),
                        const SizedBox(width: 6),
                        _ToolbarChip(
                          label: 'Image',
                          onTap: () => _insertAtCursor('\n![alt text](https://)\n'),
                        ),
                        const SizedBox(width: 6),
                        _ToolbarChip(
                          label: 'Link',
                          onTap: () => _insertAtCursor('[title](https://)'),
                        ),
                        const SizedBox(width: 6),
                        _ToolbarChip(
                          label: 'Bullet',
                          onTap: () => _insertAtCursor('\n- '),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _editorFocusNode,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText:
                      'Write markdown notes here. Example:\n## Key ideas\n- point 1\n```python\nprint("hello")\n```',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () {
                  final value = _controller.text.trim();
                  if (value.isEmpty) {
                    return;
                  }
                  widget.onSave(value);
                  _dirty = false;
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save note'),
              ),
            ),
            const Divider(height: 22),
            if (_latestSavedNote == null)
              const Text('No saved note for this page yet.')
            else
              GestureDetector(
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
                    children: [
                      Text(
                        'Saved note',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _latestSavedNote!.content,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Updated ${_latestSavedNote!.createdAt.toLocal().toIso8601String()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}
