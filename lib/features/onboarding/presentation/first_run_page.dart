import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studypdf/core/theme/design_tokens.dart';

/// Surfaces the library-root choice — which was already fully functional
/// via [FileLibraryService.setRootPath] but buried in Settings — as a
/// proper first-run step, so new users make this decision once, up front,
/// instead of discovering it later mid-use (Phase 5).
///
/// This page only decides *where the library lives* and writes that
/// choice to the same `library.rootPath` preference key
/// [WorkspaceController.loadPreferences] already reads; it does not touch
/// [FileLibraryService] directly since that's owned by the workspace
/// controller, which doesn't exist yet at this point in startup.
class FirstRunPage extends StatefulWidget {
  const FirstRunPage({super.key, required this.onComplete});

  /// Called once the user has made a choice and onboarding should finish.
  final VoidCallback onComplete;

  @override
  State<FirstRunPage> createState() => _FirstRunPageState();
}

class _FirstRunPageState extends State<FirstRunPage> {
  String? _defaultPath;
  String? _chosenPath;
  bool _picking = false;
  String? _pickError;

  @override
  void initState() {
    super.initState();
    _loadDefaultPath();
  }

  Future<void> _loadDefaultPath() async {
    // Mirrors FileLibraryService.ensureRoot()'s fallback exactly, so what
    // this page shows as "the default" is guaranteed to be the same path
    // the app would actually use if the user never opens Settings.
    final appDir = await getApplicationDocumentsDirectory();
    final defaultPath = p.join(appDir.path, 'studypdf_library');
    if (!mounted) return;
    setState(() {
      _defaultPath = defaultPath;
    });
  }

  Future<void> _pickFolder() async {
    setState(() {
      _picking = true;
      _pickError = null;
    });
    try {
      final selected = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose a folder for your StudyPDF library',
      );
      if (!mounted) return;
      if (selected == null || selected.trim().isEmpty) {
        setState(() => _picking = false);
        return;
      }
      setState(() {
        _chosenPath = selected.trim();
        _picking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pickError = 'Could not open folder picker: $e';
        _picking = false;
      });
    }
  }

  Future<void> _continue() async {
    final prefs = await SharedPreferences.getInstance();
    if (_chosenPath != null) {
      await prefs.setString(FirstRunPrefsKeys.libraryRootPath, _chosenPath!);
    }
    await prefs.setBool(FirstRunPrefsKeys.onboardingCompleted, true);
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePath = _chosenPath ?? _defaultPath;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Card(
              elevation: AppElevation.medium,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.folder_special_outlined,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Welcome to StudyPDF',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Where should your PDF library, notes, and imported files live? '
                      'You can change this later in Settings at any time.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _chosenPath != null
                                ? Icons.check_circle_outline
                                : Icons.folder_outlined,
                            size: 18,
                            color: _chosenPath != null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              effectivePath ?? 'Locating default folder…',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_pickError != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _pickError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _picking ? null : _pickFolder,
                          icon: const Icon(Icons.drive_folder_upload_outlined),
                          label: const Text('Choose a Different Folder…'),
                        ),
                        if (_chosenPath != null)
                          TextButton(
                            onPressed: _picking
                                ? null
                                : () => setState(() => _chosenPath = null),
                            child: const Text('Use Default Instead'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: effectivePath == null ? null : _continue,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Continue'),
                      ),
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

/// Persists the first-run library-root choice made on [FirstRunPage] using
/// the exact same preference keys [WorkspaceController.loadPreferences]
/// already reads on every launch, so no separate onboarding-specific
/// storage/read path is needed.
class FirstRunPrefsKeys {
  const FirstRunPrefsKeys._();

  static const String onboardingCompleted = 'onboarding.storageConfigured';
  static const String libraryRootPath = 'library.rootPath';
}
