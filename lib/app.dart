import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studypdf/core/state/ai_settings_controller.dart';
import 'package:studypdf/core/state/window_controller.dart';
import 'package:studypdf/core/state/workspace_controller.dart';
import 'package:studypdf/core/theme/app_theme.dart';
import 'package:studypdf/features/downloader/presentation/pesu_downloader_page.dart';
import 'package:studypdf/features/home/presentation/document_library_page.dart';
import 'package:studypdf/features/onboarding/presentation/first_run_page.dart';
import 'package:studypdf/features/notes/presentation/merged_notes_library_page.dart';
import 'package:studypdf/features/settings/presentation/workspace_settings_page.dart';
import 'package:studypdf/features/workspace/presentation/study_workspace_page.dart';
import 'package:studypdf/models/pdf_document.dart';

export 'package:studypdf/core/state/workspace_controller.dart' show AppSection;

class StudyPdfApp extends StatefulWidget {
  const StudyPdfApp({super.key});

  @override
  State<StudyPdfApp> createState() => _StudyPdfAppState();
}

class _StudyPdfAppState extends State<StudyPdfApp> {
  ThemeMode _themeMode = ThemeMode.system;
  // null while still checking prefs; the previously-buried
  // setRootPath/library-root capability gets a proper first-run moment
  // instead of only living in Settings (Phase 5).
  bool? _needsFirstRun;

  @override
  void initState() {
    super.initState();
    _checkFirstRun();
  }

  Future<void> _checkFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    var completed =
        prefs.getBool(FirstRunPrefsKeys.onboardingCompleted) ?? false;
    if (!completed) {
      // Grandfather in anyone upgrading from before this flag existed —
      // if a library root was already chosen (the old Settings-only
      // path), this is not actually their first run.
      final existingRoot = prefs.getString(FirstRunPrefsKeys.libraryRootPath);
      if (existingRoot != null && existingRoot.trim().isNotEmpty) {
        completed = true;
        await prefs.setBool(FirstRunPrefsKeys.onboardingCompleted, true);
      }
    }
    if (!mounted) return;
    setState(() {
      _needsFirstRun = !completed;
    });
  }

  void _handleThemeModeChanged(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final needsFirstRun = _needsFirstRun;
    return MaterialApp(
      title: 'StudyPDF',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: needsFirstRun == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : needsFirstRun
          ? FirstRunPage(
              onComplete: () => setState(() => _needsFirstRun = false),
            )
          : StudyShellPage(onThemeModeChanged: _handleThemeModeChanged),
    );
  }
}

class StudyShellPage extends StatefulWidget {
  const StudyShellPage({super.key, required this.onThemeModeChanged});

  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<StudyShellPage> createState() => _StudyShellPageState();
}

class _StudyShellPageState extends State<StudyShellPage> {
  late final WorkspaceController _workspace = WorkspaceController();
  late final AiSettingsController _ai = AiSettingsController(
    workspace: _workspace,
  );
  late final WindowController _window = WindowController(
    workspace: _workspace,
    ai: _ai,
  );

  String _query = '';

  @override
  void initState() {
    super.initState();
    _window.setupInterWindowSync();
    _initialize();
  }

  Future<void> _initialize() async {
    await _workspace.initialize();
    widget.onThemeModeChanged(_workspace.themeMode);
    await _ai.loadPreferences();
    // Fire-and-forget: populates the Settings model dropdown without
    // blocking startup on a network call.
    unawaited(_ai.loadOpenRouterFreeModels());
  }

  Future<bool> _createHomeShortcutWithFeedback({
    required String name,
    required List<String> tabIds,
    int? colorValue,
  }) async {
    final ok = await _workspace.createWorkspaceShortcut(
      name: name,
      tabIds: tabIds,
      colorValue: colorValue,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workspace "$name" already exists on Home')),
      );
    }
    return ok;
  }

  Future<bool> _createWorkspaceFromDocumentsWithFeedback(
    String name,
    List<PdfDocument> documents,
  ) async {
    final ok = await _workspace.createWorkspaceShortcutFromDocuments(
      name,
      documents,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workspace "$name" already exists on Home')),
      );
    }
    return ok;
  }

  Future<void> _updateThemeMode(ThemeMode mode) async {
    await _workspace.updateThemeMode(mode, widget.onThemeModeChanged);
  }

  Future<void> _importDownloaderPdfs() async {
    await _workspace.importDownloaderPdfs(_ai.downloaderDownloadsPath);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_workspace, _ai]),
      builder: (context, _) => _buildShell(context),
    );
  }

  Widget _buildShell(BuildContext context) {
    final filteredDocs = _workspace.documents
        .where(
          (doc) => _query.trim().isEmpty
              ? true
              : doc.title.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList(growable: false);
    final recentDocs = List<PdfDocument>.from(_workspace.documents)
      ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));

    // The PESU downloader is an opt-in module (Phase 4b) — most users
    // aren't PESU students, so its nav destination and page only exist in
    // the tree at all once enabled in Settings. Because AppSection.index
    // is no longer a reliable position once an entry can be missing, the
    // visible sections are tracked as their own list and selection is
    // resolved against *that* list rather than the raw enum index.
    final enablePesu = _workspace.workspacePreferences.enablePesuDownloader;
    final visibleSections = <AppSection>[
      AppSection.home,
      AppSection.workspace,
      if (enablePesu) AppSection.downloader,
      AppSection.notes,
      AppSection.settings,
    ];
    var selectedSectionIndex = visibleSections.indexOf(_workspace.section);
    if (selectedSectionIndex < 0) {
      selectedSectionIndex = 0;
    }

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyO):
            const OpenFileIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyT):
            const NewTabIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyE):
            const ExplainPageIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          OpenFileIntent: CallbackAction<OpenFileIntent>(
            onInvoke: (_) {
              _workspace.importPdfs(
                targetFolderPath: _workspace.selectedFolderPath,
              );
              return null;
            },
          ),
          NewTabIntent: CallbackAction<NewTabIntent>(
            onInvoke: (_) {
              _workspace.section = AppSection.home;
              _workspace.notifyChanged();
              return null;
            },
          ),
          ExplainPageIntent: CallbackAction<ExplainPageIntent>(
            onInvoke: (_) {
              _ai.runAssistant(
                providerId: _ai.activeAiProviderId,
                prompt: 'Explain this page',
              );
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('StudyPDF'),
            actions: [
              SizedBox(
                width: 320,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search documents...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                      });
                    },
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Open Home',
                onPressed: () {
                  _workspace.section = AppSection.home;
                  _workspace.notifyChanged();
                },
                icon: const Icon(Icons.home_outlined),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: selectedSectionIndex,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (index) {
                  _workspace.section = visibleSections[index];
                  _workspace.notifyChanged();
                },
                destinations: [
                  const NavigationRailDestination(
                    icon: Tooltip(
                      message: 'Home — document library',
                      child: Icon(Icons.folder_open_outlined),
                    ),
                    selectedIcon: Tooltip(
                      message: 'Home — document library',
                      child: Icon(Icons.folder_open),
                    ),
                    label: Text('Home'),
                  ),
                  const NavigationRailDestination(
                    icon: Tooltip(
                      message: 'Workspace — open PDFs and notes',
                      child: Icon(Icons.picture_as_pdf_outlined),
                    ),
                    selectedIcon: Tooltip(
                      message: 'Workspace — open PDFs and notes',
                      child: Icon(Icons.picture_as_pdf),
                    ),
                    label: Text('Workspace'),
                  ),
                  if (enablePesu)
                    const NavigationRailDestination(
                      icon: Tooltip(
                        message: 'Downloads — PESU course downloader',
                        child: Icon(Icons.download_outlined),
                      ),
                      label: Text('Downloads'),
                    ),
                  const NavigationRailDestination(
                    icon: Tooltip(
                      message: 'Notes — merged notes library',
                      child: Icon(Icons.edit_document),
                    ),
                    label: Text('Notes'),
                  ),
                  const NavigationRailDestination(
                    icon: Tooltip(
                      message: 'Settings — workspace and AI preferences',
                      child: Icon(Icons.settings_outlined),
                    ),
                    label: Text('Settings'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _workspace.loading
                    ? const Center(child: CircularProgressIndicator())
                    : IndexedStack(
                        index: selectedSectionIndex,
                        children: [
                          DocumentLibraryPage(
                            documents: filteredDocs,
                            recentDocuments: recentDocs.take(5).toList(),
                            folders: _workspace.folders,
                            shortcuts: _workspace.workspaceShortcuts,
                            selectedFolderPath: _workspace.selectedFolderPath,
                            libraryRoot: _workspace.libraryRoot,
                            onSelectFolder: _workspace.selectFolder,
                            onCreateFolder: _workspace.createFolder,
                            onImportPdf: (targetFolder) => _workspace
                                .importPdfs(targetFolderPath: targetFolder),
                            onDeleteDocument: _workspace.deleteDocument,
                            onDeleteFolder: _workspace.deleteFolder,
                            onOpenDocument: _workspace.openDocument,
                            onOpenShortcut: _workspace.openWorkspaceShortcut,
                            onDeleteShortcut: (shortcut) => _workspace
                                .deleteWorkspaceShortcutByName(shortcut.name),
                            onCreateWorkspaceFromDocuments:
                                _createWorkspaceFromDocumentsWithFeedback,
                          ),
                          StudyWorkspacePage(
                            openTabs: _workspace.openTabs,
                            activeTabId: _workspace.activeTabId,
                            activeMergedNote:
                                _workspace.activeDocument?.id.startsWith(
                                      'note-',
                                    ) ==
                                    true
                                ? _workspace.mergedNotesStore.getNoteById(
                                    _workspace.activeDocument!.id.substring(5),
                                  )
                                : null,
                            viewportData: _workspace.viewport,
                            pageAnnotations: _workspace.pageAnnotations,
                            assistantOutput: _ai.assistantOutput,
                            providers: _ai.providerRegistry.all,
                            onTabSelected: _workspace.switchTab,
                            onCloseTab: _workspace.closeTab,
                            onTabColorChanged: _workspace.setTabColor,
                            onViewportChanged: _workspace.onViewportChanged,
                            onRunPrompt: _ai.runAssistant,
                            onSaveNote: _workspace.saveAnnotation,
                            onMergeNotes: _workspace.mergeNotesForTab,
                            onMergeGroupNotes: _workspace.mergeNotesForGroup,
                            onSaveMergedNote: _workspace.saveMergedNote,
                            onRenameMergedNote: _workspace.renameMergedNote,
                            onTranscribeHandwriting: (bytes, mimeType) =>
                                _ai.transcribeHandwriting(
                                  imageBytes: bytes,
                                  mimeType: mimeType,
                                ),
                            onSaveNoteImage: (bytes, extension) =>
                                _workspace.saveNoteImage(
                                  bytes: bytes,
                                  extension: extension,
                                ),
                            activeDocument: _workspace.activeDocument,
                            onOpenExternalAiWindow:
                                _window.openExternalAiWindow,
                            onOpenExternalNotesWindow:
                                _window.openExternalNotesWindow,
                            aiDockPosition:
                                _workspace.workspacePreferences.aiDockPosition,
                            notesDockPosition: _workspace
                                .workspacePreferences
                                .notesDockPosition,
                            defaultAiVisible: _workspace
                                .workspacePreferences
                                .startWithAiVisible,
                            defaultNotesVisible: _workspace
                                .workspacePreferences
                                .startWithNotesVisible,
                            bottomPanelSpansEntireWidth: _workspace
                                .workspacePreferences
                                .bottomPanelSpansEntireWidth,
                            activeAiProviderId: _ai.activeAiProviderId,
                            onAiProviderChanged: _ai.handleAiProviderChanged,
                            onCreateHomeShortcut:
                                _createHomeShortcutWithFeedback,
                            onDeleteHomeShortcutByName:
                                _workspace.deleteWorkspaceShortcutByName,
                            onRenameHomeShortcutByName:
                                _workspace.renameWorkspaceShortcutByName,
                            onSyncHomeShortcutByName:
                                _workspace.syncWorkspaceShortcutByName,
                            shortcutLaunchRequest:
                                _workspace.shortcutLaunchRequest,
                            onShortcutLaunchConsumed:
                                _workspace.consumeShortcutLaunch,
                            codeExecutionBackend:
                                _workspace.codeExecutionBackend,
                            onCodeExecutionBackendChanged:
                                _workspace.updateCodeExecutionBackend,
                          ),
                          if (enablePesu)
                            PesuDownloaderPage(
                              downloadsPath: _ai.downloaderDownloadsPath,
                              credentialsConfigured:
                                  _ai.pesuUsername.trim().isNotEmpty &&
                                  _ai.pesuPassword.isNotEmpty,
                              onSetupEnvironment: _ai.runDownloaderSetup,
                              onFetchCourses: _ai.fetchPesuCourses,
                              onFetchUnits: _ai.fetchPesuUnits,
                              onRunDownload: _ai.runPesuDownload,
                              onImportDownloads: _importDownloaderPdfs,
                            ),
                          MergedNotesLibraryPage(
                            store: _workspace.mergedNotesStore,
                            onOpenNote: _workspace.openMergedNote,
                          ),
                          WorkspaceSettingsPage(
                            preferences: _workspace.workspacePreferences,
                            onChanged: _workspace.updateWorkspacePreferences,
                            themeMode: _workspace.themeMode,
                            onThemeModeChanged: _updateThemeMode,
                            libraryRoot: _workspace.libraryRoot,
                            onChangeLibraryRoot: _workspace.changeLibraryRoot,
                            openAiApiKey: _ai.openAiApiKey,
                            groqApiKey: _ai.groqApiKey,
                            geminiApiKey: _ai.geminiApiKey,
                            openRouterApiKey: _ai.openRouterApiKey,
                            onApiKeyChanged: _ai.updateApiKey,
                            openRouterModelId: _ai.openRouterModelId,
                            openRouterFreeModels: _ai.openRouterFreeModels,
                            openRouterFreeModelsLoading:
                                _ai.openRouterFreeModelsLoading,
                            onOpenRouterModelChanged: _ai.updateOpenRouterModel,
                            onRefreshOpenRouterModels:
                                _ai.loadOpenRouterFreeModels,
                            webSearchEnabled: _ai.webSearchEnabled,
                            crossDocRagEnabled: _ai.crossDocRagEnabled,
                            onCrossDocRagChanged: _ai.updateCrossDocRagEnabled,
                            googleSearchApiKey: _ai.googleSearchApiKey,
                            googleSearchEngineId: _ai.googleSearchCx,
                            onWebSearchSettingsChanged:
                                _ai.updateWebSearchSettings,
                            defaultAiProviderId: _ai.defaultAiProviderId,
                            onDefaultAiProviderChanged:
                                _ai.updateDefaultAiProvider,
                            pesuUsername: _ai.pesuUsername,
                            pesuPassword: _ai.pesuPassword,
                            onPesuCredentialsChanged: _ai.updatePesuCredentials,
                            codeExecutionBackend:
                                _workspace.codeExecutionBackend,
                            onCodeExecutionBackendChanged:
                                _workspace.updateCodeExecutionBackend,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OpenFileIntent extends Intent {
  const OpenFileIntent();
}

class NewTabIntent extends Intent {
  const NewTabIntent();
}

class ExplainPageIntent extends Intent {
  const ExplainPageIntent();
}
