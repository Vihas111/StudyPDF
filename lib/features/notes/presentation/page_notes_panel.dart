import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 250;
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: compact
                ? SingleChildScrollView(
                    child: _NotesBody(
                      pageNumber: widget.pageNumber,
                      controller: _controller,
                      annotations: widget.annotations,
                      onSave: widget.onSave,
                      compact: true,
                    ),
                  )
                : _NotesBody(
                    pageNumber: widget.pageNumber,
                    controller: _controller,
                    annotations: widget.annotations,
                    onSave: widget.onSave,
                    compact: false,
                  ),
          ),
        );
      },
    );
  }
}

class _NotesBody extends StatelessWidget {
  const _NotesBody({
    required this.pageNumber,
    required this.controller,
    required this.annotations,
    required this.onSave,
    required this.compact,
  });

  final int pageNumber;
  final TextEditingController controller;
  final List<Annotation> annotations;
  final ValueChanged<String> onSave;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final list = annotations.isEmpty
        ? const Center(child: Text('No notes for this page yet.'))
        : ListView.separated(
            shrinkWrap: compact,
            physics: compact
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            itemCount: annotations.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final note = annotations[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: Text(note.content),
                subtitle: Text(note.createdAt.toLocal().toIso8601String()),
              );
            },
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Page $pageNumber Notes',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          minLines: 1,
          maxLines: compact ? 2 : 3,
          decoration: const InputDecoration(
            hintText: 'Write annotation, summary, or quick notes...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () {
              onSave(controller.text);
              controller.clear();
            },
            child: const Text('Save note'),
          ),
        ),
        const Divider(),
        if (compact) list else Expanded(child: list),
      ],
    );
  }
}
