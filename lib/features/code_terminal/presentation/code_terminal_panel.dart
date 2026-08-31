import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/cpp.dart' as hl_cpp;
import 'package:highlight/languages/java.dart' as hl_java;
import 'package:highlight/languages/javascript.dart' as hl_js;
import 'package:highlight/languages/python.dart' as hl_python;
import 'package:studypdf/core/execution/code_execution_result.dart';
import 'package:studypdf/core/execution/local_process_service.dart';
import 'package:studypdf/core/execution/piston_service.dart';
import 'package:studypdf/core/theme/design_tokens.dart';

/// A dockable "run code while reading" panel. Executes via the free public
/// Piston API by default, or a locally-installed toolchain when the user
/// opts into that in Settings (see [backend]).
class CodeTerminalPanel extends StatefulWidget {
  const CodeTerminalPanel({
    super.key,
    required this.backend,
    required this.onBackendChanged,
  });

  /// 'piston' or 'local'.
  final String backend;
  final ValueChanged<String> onBackendChanged;

  @override
  State<CodeTerminalPanel> createState() => _CodeTerminalPanelState();
}

class _CodeTerminalPanelState extends State<CodeTerminalPanel> {
  final PistonService _piston = PistonService();
  final LocalProcessService _local = LocalProcessService();

  CodeLanguage _language = kSupportedCodeLanguages.first;
  late CodeController _codeController;
  final TextEditingController _stdinController = TextEditingController();

  bool _running = false;
  CodeExecutionResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController = CodeController(
      text: '',
      language: _highlightModeFor(_language),
      params: const EditorParams(tabSpaces: 4),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _stdinController.dispose();
    super.dispose();
  }

  dynamic _highlightModeFor(CodeLanguage language) {
    switch (language.highlightMode) {
      case 'python':
        return hl_python.python;
      case 'javascript':
        return hl_js.javascript;
      case 'java':
        return hl_java.java;
      case 'cpp':
        return hl_cpp.cpp;
      default:
        return hl_python.python;
    }
  }

  void _onLanguageChanged(CodeLanguage? language) {
    if (language == null || language.id == _language.id) {
      return;
    }
    final previousText = _codeController.text;
    final oldController = _codeController;
    setState(() {
      _language = language;
      // flutter_code_editor's language is set at construction time, so a
      // language switch means building a fresh controller (preserving the
      // text that was already there) rather than mutating the old one.
      _codeController = CodeController(
        text: previousText,
        language: _highlightModeFor(language),
        params: const EditorParams(tabSpaces: 4),
      );
    });
    oldController.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });
    try {
      final result = widget.backend == 'local'
          ? await _local.run(
              language: _language,
              code: _codeController.text,
              stdin: _stdinController.text,
            )
          : await _piston.run(
              language: _language,
              code: _codeController.text,
              stdin: _stdinController.text,
            );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.terminal, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Code Terminal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                DropdownButton<CodeLanguage>(
                  value: _language,
                  underline: const SizedBox.shrink(),
                  items: kSupportedCodeLanguages
                      .map(
                        (lang) => DropdownMenuItem(
                          value: lang,
                          child: Text(lang.displayName),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _onLanguageChanged,
                ),
                const Spacer(),
                Tooltip(
                  message: widget.backend == 'local'
                      ? 'Running locally — change in Settings'
                      : 'Running via Piston (free, external) — change in Settings',
                  child: Chip(
                    label: Text(
                      widget.backend == 'local' ? 'Local' : 'Piston',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: _running ? null : _run,
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Run'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: CodeTheme(
                    data: CodeThemeData(styles: monokaiSublimeTheme),
                    child: SingleChildScrollView(
                      child: CodeField(
                        controller: _codeController,
                        textStyle: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        minLines: 12,
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: TextField(
                          controller: _stdinController,
                          maxLines: 3,
                          minLines: 1,
                          decoration: const InputDecoration(
                            labelText: 'stdin (optional)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(child: _buildOutput(theme)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutput(ThemeData theme) {
    if (_error != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              _error!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: theme.colorScheme.error,
              ),
            ),
            if (widget.backend != 'local') ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Piston (the free external run service) can be unreliable — '
                'if it\'s down, switch to running locally instead.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: () => widget.onBackendChanged('local'),
                icon: const Icon(Icons.computer, size: 16),
                label: const Text('Switch to Local'),
              ),
            ],
          ],
        ),
      );
    }

    final result = _result;
    if (result == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
          'Output will appear here after you run your code.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    if (result.compileError != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: SelectableText(
          'Compile error:\n${result.compileError}',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: theme.colorScheme.error,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.stdout.isNotEmpty)
            SelectableText(
              result.stdout,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          if (result.stderr.isNotEmpty) ...[
            if (result.stdout.isNotEmpty) const SizedBox(height: AppSpacing.sm),
            SelectableText(
              result.stderr,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (result.stdout.isEmpty && result.stderr.isEmpty)
            Text(
              '(no output, exit code ${result.exitCode})',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
