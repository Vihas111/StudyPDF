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
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
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
                        DropdownButtonFormField<NotesDockOrientation>(
                          initialValue: widget.preferences.notesOrientation,
                          decoration: const InputDecoration(
                            labelText: 'Notes dock orientation',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: NotesDockOrientation.bottom,
                              child: Text('Bottom of PDF'),
                            ),
                            DropdownMenuItem(
                              value: NotesDockOrientation.right,
                              child: Text('Right of PDF'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            widget.onChanged(
                              widget.preferences.copyWith(
                                notesOrientation: value,
                              ),
                            );
                          },
                        ),
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
