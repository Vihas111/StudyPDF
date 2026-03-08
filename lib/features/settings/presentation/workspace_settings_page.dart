import 'package:flutter/material.dart';
import 'package:studypdf/models/workspace_preferences.dart';

class WorkspaceSettingsPage extends StatefulWidget {
  const WorkspaceSettingsPage({
    super.key,
    required this.preferences,
    required this.onChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.libraryRoot,
    required this.onChangeLibraryRoot,
    required this.openAiApiKey,
    required this.groqApiKey,
    required this.geminiApiKey,
    required this.onApiKeyChanged,
    required this.webSearchEnabled,
    required this.crossDocRagEnabled,
    required this.onCrossDocRagChanged,
    required this.googleSearchApiKey,
    required this.googleSearchEngineId,
    required this.onWebSearchSettingsChanged,
    required this.defaultAiProviderId,
    required this.onDefaultAiProviderChanged,
    required this.pesuUsername,
    required this.pesuPassword,
    required this.onPesuCredentialsChanged,
  });

  final WorkspacePreferences preferences;
  final ValueChanged<WorkspacePreferences> onChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String libraryRoot;
  final Future<void> Function() onChangeLibraryRoot;
  final String openAiApiKey;
  final String groqApiKey;
  final String geminiApiKey;
  final Future<void> Function({required String providerId, required String key})
  onApiKeyChanged;
  final bool webSearchEnabled;
  final bool crossDocRagEnabled;
  final ValueChanged<bool> onCrossDocRagChanged;
  final String googleSearchApiKey;
  final String googleSearchEngineId;
  final Future<void> Function({
    required bool enabled,
    required String apiKey,
    required String searchEngineId,
  })
  onWebSearchSettingsChanged;
  final String defaultAiProviderId;
  final Future<void> Function(String providerId) onDefaultAiProviderChanged;
  final String pesuUsername;
  final String pesuPassword;
  final Future<void> Function({
    required String username,
    required String password,
  })
  onPesuCredentialsChanged;

  @override
  State<WorkspaceSettingsPage> createState() => _WorkspaceSettingsPageState();
}

class _WorkspaceSettingsPageState extends State<WorkspaceSettingsPage> {
  late final TextEditingController _openAiController;
  late final TextEditingController _groqController;
  late final TextEditingController _geminiController;
  late final TextEditingController _googleApiController;
  late final TextEditingController _googleCxController;
  late final TextEditingController _pesuUsernameController;
  late final TextEditingController _pesuPasswordController;
  bool _hideOpenAiKey = true;
  bool _hideGroqKey = true;
  bool _hideGeminiKey = true;
  bool _hideGoogleApiKey = true;
  bool _hidePesuPassword = true;
  late bool _webSearchEnabled;

  @override
  void initState() {
    super.initState();
    _openAiController = TextEditingController(text: widget.openAiApiKey);
    _groqController = TextEditingController(text: widget.groqApiKey);
    _geminiController = TextEditingController(text: widget.geminiApiKey);
    _googleApiController = TextEditingController(
      text: widget.googleSearchApiKey,
    );
    _googleCxController = TextEditingController(
      text: widget.googleSearchEngineId,
    );
    _pesuUsernameController = TextEditingController(text: widget.pesuUsername);
    _pesuPasswordController = TextEditingController(text: widget.pesuPassword);
    _webSearchEnabled = widget.webSearchEnabled;
  }

  String _dockLabel(PanelDockPosition position) {
    switch (position) {
      case PanelDockPosition.left:
        return 'Left of PDF';
      case PanelDockPosition.right:
        return 'Right of PDF';
      case PanelDockPosition.bottom:
        return 'Bottom of PDF';
    }
  }

  Widget _layoutPreview() {
    Widget panelChip(String text, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11)),
      );
    }

    final ai = panelChip('AI', Colors.lightBlue.withValues(alpha: 0.30));
    final notes = panelChip('Notes', Colors.orange.withValues(alpha: 0.30));
    final center = Expanded(
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: Text('PDF')),
      ),
    );

    Widget sideColumn(List<Widget> children) {
      if (children.isEmpty) {
        return const SizedBox.shrink();
      }
      return SizedBox(
        width: 84,
        child: Column(
          children: children
              .map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: w,
                ),
              )
              .toList(growable: false),
        ),
      );
    }

    final left = <Widget>[];
    final right = <Widget>[];
    final bottom = <Widget>[];

    void place(Widget w, PanelDockPosition p) {
      switch (p) {
        case PanelDockPosition.left:
          left.add(w);
          break;
        case PanelDockPosition.right:
          right.add(w);
          break;
        case PanelDockPosition.bottom:
          bottom.add(w);
          break;
      }
    }

    place(ai, widget.preferences.aiDockPosition);

    // Mirror the mutual-exclusion rule from the workspace layout:
    // if Notes is configured to the same side as AI, show it on the opposite side.
    PanelDockPosition effectiveNotesPos = widget.preferences.notesDockPosition;
    if (effectiveNotesPos == widget.preferences.aiDockPosition) {
      if (effectiveNotesPos == PanelDockPosition.left) {
        effectiveNotesPos = PanelDockPosition.right;
      } else if (effectiveNotesPos == PanelDockPosition.right) {
        effectiveNotesPos = PanelDockPosition.left;
      } else {
        effectiveNotesPos = PanelDockPosition.right;
      }
    }
    place(notes, effectiveNotesPos);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Layout preview', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sideColumn(left),
              if (left.isNotEmpty) const SizedBox(width: 8),
              center,
              if (right.isNotEmpty) const SizedBox(width: 8),
              sideColumn(right),
            ],
          ),
          if (bottom.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: bottom),
          ],
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(covariant WorkspaceSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openAiApiKey != widget.openAiApiKey &&
        widget.openAiApiKey != _openAiController.text) {
      _openAiController.text = widget.openAiApiKey;
    }
    if (oldWidget.groqApiKey != widget.groqApiKey &&
        widget.groqApiKey != _groqController.text) {
      _groqController.text = widget.groqApiKey;
    }
    if (oldWidget.geminiApiKey != widget.geminiApiKey &&
        widget.geminiApiKey != _geminiController.text) {
      _geminiController.text = widget.geminiApiKey;
    }
    if (oldWidget.googleSearchApiKey != widget.googleSearchApiKey &&
        widget.googleSearchApiKey != _googleApiController.text) {
      _googleApiController.text = widget.googleSearchApiKey;
    }
    if (oldWidget.googleSearchEngineId != widget.googleSearchEngineId &&
        widget.googleSearchEngineId != _googleCxController.text) {
      _googleCxController.text = widget.googleSearchEngineId;
    }
    if (oldWidget.webSearchEnabled != widget.webSearchEnabled) {
      _webSearchEnabled = widget.webSearchEnabled;
    }
    if (oldWidget.pesuUsername != widget.pesuUsername &&
        widget.pesuUsername != _pesuUsernameController.text) {
      _pesuUsernameController.text = widget.pesuUsername;
    }
    if (oldWidget.pesuPassword != widget.pesuPassword &&
        widget.pesuPassword != _pesuPasswordController.text) {
      _pesuPasswordController.text = widget.pesuPassword;
    }
  }

  @override
  void dispose() {
    _openAiController.dispose();
    _groqController.dispose();
    _geminiController.dispose();
    _googleApiController.dispose();
    _googleCxController.dispose();
    _pesuUsernameController.dispose();
    _pesuPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey(
    String providerId,
    TextEditingController controller,
    String label,
  ) async {
    await widget.onApiKeyChanged(providerId: providerId, key: controller.text);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label API key saved')));
  }

  Future<void> _saveWebSettings() async {
    await widget.onWebSearchSettingsChanged(
      enabled: _webSearchEnabled,
      apiKey: _googleApiController.text,
      searchEngineId: _googleCxController.text,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Web search settings saved')));
  }

  Future<void> _savePesuCredentials() async {
    await widget.onPesuCredentialsChanged(
      username: _pesuUsernameController.text,
      password: _pesuPasswordController.text,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PESU credentials saved')));
  }

  Widget _apiKeyField({
    required TextEditingController controller,
    required String label,
    required bool hidden,
    required VoidCallback onToggleHidden,
    required VoidCallback onSave,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: hidden,
          onSubmitted: (_) => onSave(),
          decoration: InputDecoration(
            labelText: '$label API Key',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: hidden ? 'Show key' : 'Hide key',
              onPressed: onToggleHidden,
              icon: Icon(
                hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: onSave, child: Text('Save $label Key')),
      ],
    );
  }

  Widget _settingsCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  void _showAiApiHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Where to get AI API keys'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OpenAI: platform.openai.com/api-keys'),
            SizedBox(height: 6),
            Text('Groq: console.groq.com/keys'),
            SizedBox(height: 6),
            Text('Gemini: aistudio.google.com/app/apikey'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showWebSearchHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Where to get Web Search keys'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Enable Custom Search JSON API in Google Cloud.'),
            SizedBox(height: 6),
            Text('2. Create an API key in Google Cloud Console.'),
            SizedBox(height: 6),
            Text('3. Create a Programmable Search Engine and copy its CX ID.'),
            SizedBox(height: 6),
            Text('Google Cloud: console.cloud.google.com'),
            SizedBox(height: 4),
            Text('Programmable Search: programmablesearchengine.google.com'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _settingsCard(
                      context: context,
                      title: 'Theme',
                      children: [
                        DropdownButtonFormField<ThemeMode>(
                          initialValue: widget.themeMode,
                          decoration: const InputDecoration(
                            labelText: 'Theme mode',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: ThemeMode.system,
                              child: Text('System'),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.light,
                              child: Text('Light'),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.dark,
                              child: Text('Dark'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              widget.onThemeModeChanged(value);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _settingsCard(
                      context: context,
                      title: 'AI Settings',
                      trailing: IconButton(
                        tooltip: 'Where to get API keys',
                        onPressed: _showAiApiHelpDialog,
                        icon: const Icon(Icons.help_outline),
                      ),
                      children: [
                        _apiKeyField(
                          controller: _openAiController,
                          label: 'OpenAI',
                          hidden: _hideOpenAiKey,
                          onToggleHidden: () {
                            setState(() {
                              _hideOpenAiKey = !_hideOpenAiKey;
                            });
                          },
                          onSave: () => _saveApiKey(
                            'openai',
                            _openAiController,
                            'OpenAI',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _apiKeyField(
                          controller: _groqController,
                          label: 'Groq',
                          hidden: _hideGroqKey,
                          onToggleHidden: () {
                            setState(() {
                              _hideGroqKey = !_hideGroqKey;
                            });
                          },
                          onSave: () =>
                              _saveApiKey('groq', _groqController, 'Groq'),
                        ),
                        const SizedBox(height: 8),
                        _apiKeyField(
                          controller: _geminiController,
                          label: 'Gemini',
                          hidden: _hideGeminiKey,
                          onToggleHidden: () {
                            setState(() {
                              _hideGeminiKey = !_hideGeminiKey;
                            });
                          },
                          onSave: () => _saveApiKey(
                            'gemini',
                            _geminiController,
                            'Gemini',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Query all open tabs (Cross-Document RAG)'),
                          subtitle: const Text(
                            'When enabled, the AI will search across all open PDFs instead of just the active one.(Good for comparing across documents but more token expensive)',
                          ),
                          value: widget.crossDocRagEnabled,
                          onChanged: widget.onCrossDocRagChanged,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Enable web search fallback'),
                                subtitle: const Text(
                                  'Uses Google Custom Search snippets when PDF context is not enough.',
                                ),
                                value: _webSearchEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _webSearchEnabled = value;
                                  });
                                },
                              ),
                            ),
                            IconButton(
                              tooltip: 'Where to get Web Search keys',
                              onPressed: _showWebSearchHelpDialog,
                              icon: const Icon(Icons.help_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _googleApiController,
                          obscureText: _hideGoogleApiKey,
                          onSubmitted: (_) => _saveWebSettings(),
                          decoration: InputDecoration(
                            labelText: 'Google Search API Key',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: _hideGoogleApiKey
                                  ? 'Show key'
                                  : 'Hide key',
                              onPressed: () {
                                setState(() {
                                  _hideGoogleApiKey = !_hideGoogleApiKey;
                                });
                              },
                              icon: Icon(
                                _hideGoogleApiKey
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _googleCxController,
                          onSubmitted: (_) => _saveWebSettings(),
                          decoration: const InputDecoration(
                            labelText: 'Google Search Engine ID (CX)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _saveWebSettings,
                          child: const Text('Save Web Search Settings'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _settingsCard(
                      context: context,
                      title: 'Workspace Defaults',
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: widget.defaultAiProviderId,
                          decoration: const InputDecoration(
                            labelText: 'Default AI provider',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'openai',
                              child: Text('OpenAI'),
                            ),
                            DropdownMenuItem(
                              value: 'groq',
                              child: Text('Groq'),
                            ),
                            DropdownMenuItem(
                              value: 'gemini',
                              child: Text('Google Gemini'),
                            ),
                            DropdownMenuItem(
                              value: 'ollama',
                              child: Text('Ollama'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              widget.onDefaultAiProviderChanged(value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<PanelDockPosition>(
                          initialValue: widget.preferences.aiDockPosition,
                          decoration: const InputDecoration(
                            labelText: 'AI panel dock position',
                            border: OutlineInputBorder(),
                          ),
                          items: PanelDockPosition.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_dockLabel(value)),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            // If the new AI position conflicts with Notes, flip Notes too.
                            var newPrefs = widget.preferences.copyWith(
                              aiDockPosition: value,
                            );
                            if (newPrefs.notesDockPosition == value) {
                              final flipped = value == PanelDockPosition.left
                                  ? PanelDockPosition.right
                                  : value == PanelDockPosition.right
                                      ? PanelDockPosition.left
                                      : PanelDockPosition.right;
                              newPrefs = newPrefs.copyWith(
                                notesDockPosition: flipped,
                              );
                            }
                            widget.onChanged(newPrefs);
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<PanelDockPosition>(
                          initialValue: widget.preferences.notesDockPosition,
                          decoration: const InputDecoration(
                            labelText: 'Notes panel dock position',
                            border: OutlineInputBorder(),
                          ),
                          items: PanelDockPosition.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_dockLabel(value)),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            // Enforce mutual exclusion: if chosen position matches AI, flip to opposite.
                            PanelDockPosition effective = value;
                            if (effective == widget.preferences.aiDockPosition) {
                              effective = effective == PanelDockPosition.left
                                  ? PanelDockPosition.right
                                  : effective == PanelDockPosition.right
                                      ? PanelDockPosition.left
                                      : PanelDockPosition.right;
                            }
                            widget.onChanged(
                              widget.preferences.copyWith(
                                notesDockPosition: effective,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _layoutPreview(),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Start with AI sidebar visible'),
                          value: widget.preferences.startWithAiVisible,
                          onChanged: (value) {
                            widget.onChanged(
                              widget.preferences.copyWith(
                                startWithAiVisible: value,
                              ),
                            );
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Start with Notes panel visible'),
                          value: widget.preferences.startWithNotesVisible,
                          onChanged: (value) {
                            widget.onChanged(
                              widget.preferences.copyWith(
                                startWithNotesVisible: value,
                              ),
                            );
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Bottom panel spans full width'),
                          subtitle: const Text('When disabled, side panels span top-to-bottom constraints'),
                          value: widget.preferences.bottomPanelSpansEntireWidth,
                          onChanged: (value) {
                            widget.onChanged(
                              widget.preferences.copyWith(
                                bottomPanelSpansEntireWidth: value,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Library root',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.libraryRoot,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: widget.onChangeLibraryRoot,
                          icon: const Icon(Icons.drive_folder_upload_outlined),
                          label: const Text('Change Root Directory'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _settingsCard(
                      context: context,
                      title: 'Downloader Credentials',
                      children: [
                        TextField(
                          controller: _pesuUsernameController,
                          onSubmitted: (_) => _savePesuCredentials(),
                          decoration: const InputDecoration(
                            labelText: 'PESU Username (SRN)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _pesuPasswordController,
                          obscureText: _hidePesuPassword,
                          onSubmitted: (_) => _savePesuCredentials(),
                          decoration: InputDecoration(
                            labelText: 'PESU Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: _hidePesuPassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () {
                                setState(() {
                                  _hidePesuPassword = !_hidePesuPassword;
                                });
                              },
                              icon: Icon(
                                _hidePesuPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _savePesuCredentials,
                          child: const Text('Save Downloader Credentials'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
