import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  void _insertWrap(String left, String right) {
    final value = controller.value;
    final selection = value.selection;
    if (!selection.isValid) {
      final text = value.text;
      final next = text + left + right;
      final cursor = text.length + left.length;
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: cursor),
      );
      focusNode.requestFocus();
      return;
    }

    final text = value.text;
    final start = selection.start;
    final end = selection.end;
    
    if (start == end) {
      // Empty selection: wrap at cursor
      final next = text.replaceRange(start, end, '$left$right');
      final cursor = start + left.length;
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: cursor),
      );
    } else {
      // Selected text: wrap around selection
      final selected = text.substring(start, end);
      final next = text.replaceRange(start, end, '$left$selected$right');
      final cursor = start + left.length + selected.length + right.length;
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: cursor),
      );
    }
    focusNode.requestFocus();
  }

  void _insertAtCursor(String snippet) {
    final value = controller.value;
    final selection = value.selection;
    final text = value.text;
    
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    
    final next = text.replaceRange(start, end, snippet);
    final cursor = start + snippet.length;
    
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cursor),
    );
    focusNode.requestFocus();
  }

  Future<void> _pickImage(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result == null || result.files.single.path == null) return;

      final sourceFile = File(result.files.single.path!);
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory('${appDir.path}/studypdf/attachments');
      
      if (!await attachmentsDir.exists()) {
        await attachmentsDir.create(recursive: true);
      }

      final ext = sourceFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final destFile = File('${attachmentsDir.path}/$fileName');
      
      await sourceFile.copy(destFile.path);

      final markdownImage = '\n![image](file://${destFile.path.replaceAll('\\', '/')})\n';
      _insertAtCursor(markdownImage);
      
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to attach image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ToolbarButton(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            onTap: () => _insertWrap('**', '**'),
          ),
          _ToolbarButton(
            icon: Icons.format_italic,
            tooltip: 'Italic',
            onTap: () => _insertWrap('*', '*'),
          ),
          _ToolbarButton(
            icon: Icons.format_underlined,
            tooltip: 'Underline',
            onTap: () => _insertWrap('<u>', '</u>'),
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.code,
            tooltip: 'Inline Code',
            onTap: () => _insertWrap('`', '`'),
          ),
          _ToolbarButton(
            icon: Icons.integration_instructions_outlined,
            tooltip: 'Code Block',
            onTap: () => _insertWrap('\n```\n', '\n```\n'),
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.format_list_bulleted,
            tooltip: 'Bullet List',
            onTap: () => _insertAtCursor('\n- '),
          ),
          _ToolbarButton(
            icon: Icons.link,
            tooltip: 'Link',
            onTap: () => _insertWrap('[', '](https://)'),
          ),
          _ToolbarButton(
            icon: Icons.image_outlined,
            tooltip: 'Insert Image',
            onTap: () => _pickImage(context),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onTap,
      splashRadius: 20,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
