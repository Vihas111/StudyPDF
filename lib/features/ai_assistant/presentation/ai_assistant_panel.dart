import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:studypdf/core/ai/ai_provider.dart';
import 'package:studypdf/features/notes/presentation/markdown_extensions.dart';

class AIAssistantPanel extends StatefulWidget {
  const AIAssistantPanel({
    super.key,
    required this.providers,
    required this.onRunPrompt,
    this.initialProviderId,
    this.onProviderChanged,
  });

  final List<AIProvider> providers;
  final Future<String> Function({
    required String providerId,
    required String prompt,
  })
  onRunPrompt;
  final String? initialProviderId;
  final ValueChanged<String>? onProviderChanged;

  @override
  State<AIAssistantPanel> createState() => _AIAssistantPanelState();
}

class _AIAssistantPanelState extends State<AIAssistantPanel> {
  late String _providerId;
  final TextEditingController _inputController = TextEditingController(
    text: 'Explain this page',
  );
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    final preferred = widget.initialProviderId;
    final preferredExists =
        preferred != null &&
        widget.providers.any((provider) => provider.id == preferred);
    _providerId =
        (preferredExists ? preferred : null) ?? widget.providers.first.id;
    _messages.add(
      const _ChatMessage(
        role: _ChatRole.assistant,
        text:
            'Ask anything about this PDF. I will use retrieved PDF context to answer.',
      ),
    );
  }

  @override
  void didUpdateWidget(covariant AIAssistantPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final preferred = widget.initialProviderId;
    final exists =
        preferred != null &&
        widget.providers.any((provider) => provider.id == preferred);
    if (!exists || preferred == _providerId) {
      return;
    }
    setState(() {
      _providerId = preferred;
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt(String prompt, {bool clearComposer = true}) async {
    final cleaned = prompt.trim();
    if (cleaned.isEmpty || _running) {
      return;
    }
    if (clearComposer) {
      _inputController.clear();
      _inputFocusNode.requestFocus();
    }

    setState(() {
      _running = true;
      _messages.add(_ChatMessage(role: _ChatRole.user, text: cleaned));
    });
    _scrollToBottom();

    try {
      final response = await widget.onRunPrompt(
        providerId: _providerId,
        prompt: cleaned,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(_ChatMessage(role: _ChatRole.assistant, text: response));
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _ChatMessage(
            role: _ChatRole.assistant,
            text: 'AI request failed: ${e.toString()}',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Build the top section (header, provider dropdown, action buttons)
          final topSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AI Assistant',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _providerId,
                items: widget.providers
                    .map(
                      (provider) => DropdownMenuItem<String>(
                        value: provider.id,
                        child: Text(provider.displayName),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _providerId = value;
                    });
                    widget.onProviderChanged?.call(value);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Provider',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _running
                        ? null
                        : () => _sendPrompt(
                            'Explain this page',
                            clearComposer: false,
                          ),
                    child: const Text('Explain'),
                  ),
                  FilledButton.tonal(
                    onPressed: _running
                        ? null
                        : () => _sendPrompt(
                            'Summarize this page',
                            clearComposer: false,
                          ),
                    child: const Text('Summarize'),
                  ),
                  OutlinedButton(
                    onPressed: _running
                        ? null
                        : () => _sendPrompt(_inputController.text),
                    child: const Text('Run custom'),
                  ),
                  TextButton(
                    onPressed: _running
                        ? null
                        : () {
                            setState(() {
                              _messages.clear();
                            });
                          },
                    child: const Text('Clear chat'),
                  ),
                ],
              ),
              if (_running) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2),
              ],
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
            ],
          );

          // Build the message input
          final inputSection = Focus(
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) {
                return KeyEventResult.ignored;
              }
              if (event.logicalKey == LogicalKeyboardKey.enter &&
                  !HardwareKeyboard.instance.isShiftPressed) {
                if (!_running) {
                  _sendPrompt(_inputController.text);
                }
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              focusNode: _inputFocusNode,
              controller: _inputController,
              minLines: 2,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: 'Message',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Send',
                  onPressed: _running
                      ? null
                      : () => _sendPrompt(_inputController.text),
                  icon: const Icon(Icons.send),
                ),
              ),
            ),
          );

          // Chat list fills all remaining vertical space
          final chatList = Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              controller: _scrollController,
              itemCount: _messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.role == _ChatRole.user;
                final align = isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft;
                final color = isUser
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest;
                return Align(
                  alignment: align,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: MarkdownBody(
                          data: msg.text,
                          selectable: true,
                          extensionSet: md.ExtensionSet.gitHubWeb,
                          inlineSyntaxes: [UnderlineSyntax()],
                          builders: {'u': UnderlineBuilder()},
                          imageBuilder: (uri, title, alt) {
                            if (uri.scheme == 'file') {
                              return Image.file(File(uri.path));
                            }
                            return const SizedBox.shrink();
                          },
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isUser ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                            ),
                            strong: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isUser ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );

          // Use a Column that fills the available constraints:
          // - top section at the top (natural size)
          // - chat fills all remaining space (Expanded)
          // - input pinned at the bottom (natural size)
          return Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: constraints.maxWidth - 24,
              height: constraints.maxHeight.isFinite
                  ? constraints.maxHeight - 24
                  : null,
              child: Column(
                mainAxisSize: constraints.maxHeight.isFinite
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  topSection,
                  if (constraints.maxHeight.isFinite)
                    Expanded(child: chatList)
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 200, maxHeight: 400),
                      child: chatList,
                    ),
                  const SizedBox(height: 8),
                  inputSection,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _ChatRole { user, assistant }

class _ChatMessage {
  const _ChatMessage({required this.role, required this.text});

  final _ChatRole role;
  final String text;
}
