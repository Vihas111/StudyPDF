import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studypdf/core/ai/ai_provider_registry.dart';
import 'package:studypdf/core/ai/rag/google_search_service.dart';
import 'package:studypdf/core/ai/rag/pdf_rag_service.dart';
import 'package:studypdf/core/storage/file_library_service.dart';
import 'package:studypdf/core/storage/local_store.dart';
import 'package:studypdf/features/downloader/presentation/pesu_downloader_page.dart';
import 'package:studypdf/features/home/presentation/document_library_page.dart';
import 'package:studypdf/features/settings/presentation/workspace_settings_page.dart';
import 'package:studypdf/features/workspace/presentation/study_workspace_page.dart';
import 'package:studypdf/models/annotation.dart';
import 'package:studypdf/models/library_folder.dart';
import 'package:studypdf/models/pdf_document.dart';
import 'package:studypdf/models/pdf_viewport_data.dart';
import 'package:studypdf/models/workspace_preferences.dart';
import 'package:studypdf/models/workspace_shortcut.dart';

class StudyPdfApp extends StatefulWidget {
  const StudyPdfApp({super.key});

  @override
  State<StudyPdfApp> createState() => _StudyPdfAppState();
}

class _StudyPdfAppState extends State<StudyPdfApp> {
  ThemeMode _themeMode = ThemeMode.system;

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
    return MaterialApp(
      title: 'StudyPDF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF255F85)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF255F85),
        ),
      ),
      themeMode: _themeMode,
      home: StudyShellPage(onThemeModeChanged: _handleThemeModeChanged),
    );
  }
}

enum AppSection { home, workspace, downloader, settings }

class StudyShellPage extends StatefulWidget {
  const StudyShellPage({super.key, required this.onThemeModeChanged});

  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<StudyShellPage> createState() => _StudyShellPageState();
}

class _StudyShellPageState extends State<StudyShellPage> {
  final LocalStore _store = LocalStore();
  final AIProviderRegistry _providerRegistry = AIProviderRegistry();
  final GoogleSearchService _googleSearchService = GoogleSearchService();
  final PdfRagService _ragService = PdfRagService();
  final FileLibraryService _fileLibraryService = FileLibraryService();

  AppSection _section = AppSection.home;
  String _query = '';
  String _selectedFolderPath = '';
  bool _loading = true;
  String _libraryRoot = '';
  WorkspacePreferences _workspacePreferences = const WorkspacePreferences();
  ThemeMode _themeMode = ThemeMode.system;
  String _openAiApiKey = '';
  String _groqApiKey = '';
  String _geminiApiKey = '';
  String _defaultAiProviderId = 'openai';
  bool _webSearchEnabled = false;
  String _googleSearchApiKey = '';
  String _googleSearchCx = '';
  String _pesuUsername = '';
  String _pesuPassword = '';
  List<WorkspaceShortcut> _workspaceShortcuts = const [];
  Map<String, int> _tabColorsByDocumentId = <String, int>{};
  Map<String, int> _lastReadPageByDocumentId = <String, int>{};
  ShortcutLaunchRequest? _shortcutLaunchRequest;
  int _shortcutLaunchNonce = 0;

  List<PdfDocument> _documents = [];
  List<LibraryFolder> _folders = [];
  List<PdfDocument> _openTabs = [];
  String? _activeTabId;
  PdfViewportData _viewport = const PdfViewportData(
    currentPage: 1,
    totalPages: 1,
    pageText: '',
  );

  String _assistantOutput =
      'AI output will appear here. Select a prompt like "Explain this page".';

  List<Annotation> _pageAnnotations = const [];
  final Set<int> _externalAiWindowIds = <int>{};
  final Set<int> _externalNotesWindowIds = <int>{};

  PdfDocument? get _activeDocument {
    if (_activeTabId == null) {
      return null;
    }
    for (final doc in _openTabs) {
      if (doc.id == _activeTabId) {
        return doc;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _setupInterWindowSync();
    _initialize();
  }

  void _setupInterWindowSync() {
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'externalWindowReady') {
        final data = (call.arguments as Map).cast<String, dynamic>();
        final panel = data['panel'] as String? ?? '';
        if (panel == 'ai') {
          _externalAiWindowIds.add(fromWindowId);
          await _pushAiStateToWindow(fromWindowId);
        } else if (panel == 'notes') {
          _externalNotesWindowIds.add(fromWindowId);
          await _pushNotesStateToWindow(fromWindowId);
        }
        return {'ok': true};
      }

      if (call.method == 'externalNoteSaved') {
        final data = (call.arguments as Map).cast<String, dynamic>();
        final annotation = Annotation(
          id:
              data['id'] as String? ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          pdfId: data['pdfId'] as String? ?? '',
          pageNumber: data['pageNumber'] as int? ?? 1,
          content: data['content'] as String? ?? '',
          createdAt:
              DateTime.tryParse(data['createdAt'] as String? ?? '') ??
              DateTime.now(),
        );
        _store.addAnnotation(annotation);
        if (_activeDocument?.id == annotation.pdfId &&
            _viewport.currentPage == annotation.pageNumber) {
          _refreshAnnotations();
          if (mounted) {
            setState(() {});
          }
        }
        await _broadcastNotesState();
        return {'ok': true};
      }

      if (call.method == 'externalAiOutputUpdated') {
        final data = (call.arguments as Map).cast<String, dynamic>();
        final text = data['assistantOutput'] as String? ?? '';
        if (text.isNotEmpty) {
          _assistantOutput = text;
          if (mounted) {
            setState(() {});
          }
          await _broadcastAiState();
        }
        return {'ok': true};
      }

      return null;
    });
  }

  Future<void> _initialize() async {
    await _loadAppPreferences();
    _libraryRoot = await _fileLibraryService.getRootPath();
    await _reloadLibrary();
  }

  Future<void> _loadAppPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeRaw = prefs.getString('app.themeMode') ?? 'system';
    _themeMode = _themeModeFromString(themeRaw);
    widget.onThemeModeChanged(_themeMode);
    _openAiApiKey = prefs.getString('ai.openaiApiKey') ?? '';
    _groqApiKey =
        prefs.getString('ai.groqApiKey') ??
        prefs.getString('ai.anthropicApiKey') ??
        '';
    _geminiApiKey = prefs.getString('ai.geminiApiKey') ?? '';
    final rawDefault = prefs.getString('ai.defaultProviderId') ?? 'openai';
    _defaultAiProviderId = rawDefault == 'anthropic' ? 'groq' : rawDefault;
    _webSearchEnabled = prefs.getBool('ai.webSearchEnabled') ?? false;
    _googleSearchApiKey = prefs.getString('ai.googleSearchApiKey') ?? '';
    _googleSearchCx = prefs.getString('ai.googleSearchEngineId') ?? '';
    _pesuUsername = prefs.getString('pesu.username') ?? '';
    _pesuPassword = prefs.getString('pesu.password') ?? '';

    final customRoot = prefs.getString('library.rootPath');
    if (customRoot != null && customRoot.trim().isNotEmpty) {
      await _fileLibraryService.setRootPath(customRoot);
    }

    final orientationRaw =
        prefs.getString('workspace.notesOrientation') ?? 'bottom';
    final startAi = prefs.getBool('workspace.startWithAiVisible') ?? true;
    final startNotes = prefs.getBool('workspace.startWithNotesVisible') ?? true;

    _workspacePreferences = WorkspacePreferences(
      notesOrientation: orientationRaw == 'right'
          ? NotesDockOrientation.right
          : NotesDockOrientation.bottom,
      startWithAiVisible: startAi,
      startWithNotesVisible: startNotes,
    );

    final shortcutsRaw = prefs.getString('workspace.shortcuts');
    if (shortcutsRaw != null && shortcutsRaw.trim().isNotEmpty) {
      try {
        _workspaceShortcuts = WorkspaceShortcut.decodeList(shortcutsRaw);
      } catch (_) {
        _workspaceShortcuts = const [];
      }
    } else {
      _workspaceShortcuts = const [];
    }

    final tabColorsRaw = prefs.getString('workspace.tabColors');
    if (tabColorsRaw != null && tabColorsRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(tabColorsRaw);
        if (decoded is Map<String, dynamic>) {
          _tabColorsByDocumentId = decoded.map(
            (key, value) => MapEntry(key, value as int),
          );
        } else {
          _tabColorsByDocumentId = <String, int>{};
        }
      } catch (_) {
        _tabColorsByDocumentId = <String, int>{};
      }
    } else {
      _tabColorsByDocumentId = <String, int>{};
    }

    final lastPagesRaw = prefs.getString('workspace.lastReadPages');
    if (lastPagesRaw != null && lastPagesRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(lastPagesRaw);
        if (decoded is Map<String, dynamic>) {
          _lastReadPageByDocumentId = decoded.map(
            (key, value) => MapEntry(key, (value as num).toInt()),
          );
        } else {
          _lastReadPageByDocumentId = <String, int>{};
        }
      } catch (_) {
        _lastReadPageByDocumentId = <String, int>{};
      }
    } else {
      _lastReadPageByDocumentId = <String, int>{};
    }
  }

  Future<void> _updateWorkspacePreferences(WorkspacePreferences updated) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workspace.notesOrientation',
      updated.notesOrientation == NotesDockOrientation.right
          ? 'right'
          : 'bottom',
    );
    await prefs.setBool(
      'workspace.startWithAiVisible',
      updated.startWithAiVisible,
    );
    await prefs.setBool(
      'workspace.startWithNotesVisible',
      updated.startWithNotesVisible,
    );

    if (mounted) {
      setState(() {
        _workspacePreferences = updated;
      });
    }
  }

  ThemeMode _themeModeFromString(String raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> _updateThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app.themeMode', _themeModeToString(mode));
    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = mode;
    });
    widget.onThemeModeChanged(mode);
  }

  Future<void> _updateApiKey({
    required String providerId,
    required String key,
  }) async {
    final trimmed = key.trim();
    final prefs = await SharedPreferences.getInstance();
    final prefKey = switch (providerId) {
      'openai' => 'ai.openaiApiKey',
      'groq' => 'ai.groqApiKey',
      'gemini' => 'ai.geminiApiKey',
      _ => '',
    };
    if (prefKey.isEmpty) {
      return;
    }
    await prefs.setString(prefKey, trimmed);
    if (!mounted) {
      return;
    }
    setState(() {
      switch (providerId) {
        case 'openai':
          _openAiApiKey = trimmed;
          break;
        case 'groq':
          _groqApiKey = trimmed;
          break;
        case 'gemini':
          _geminiApiKey = trimmed;
          break;
        default:
          break;
      }
    });
  }

  Future<void> _updateWebSearchSettings({
    required bool enabled,
    required String apiKey,
    required String searchEngineId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai.webSearchEnabled', enabled);
    await prefs.setString('ai.googleSearchApiKey', apiKey.trim());
    await prefs.setString('ai.googleSearchEngineId', searchEngineId.trim());
    if (!mounted) {
      return;
    }
    setState(() {
      _webSearchEnabled = enabled;
      _googleSearchApiKey = apiKey.trim();
      _googleSearchCx = searchEngineId.trim();
    });
  }

  Future<void> _updateDefaultAiProvider(String providerId) async {
    final allowed = {'openai', 'groq', 'gemini', 'ollama'};
    if (!allowed.contains(providerId)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai.defaultProviderId', providerId);
    if (!mounted) {
      return;
    }
    setState(() {
      _defaultAiProviderId = providerId;
    });
  }

  Future<void> _updatePesuCredentials({
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pesu.username', username.trim());
    await prefs.setString('pesu.password', password);
    if (!mounted) {
      return;
    }
    setState(() {
      _pesuUsername = username.trim();
      _pesuPassword = password;
    });
  }

  Future<void> _changeLibraryRoot() async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose StudyPDF Library Root',
    );
    if (selected == null || selected.trim().isEmpty) {
      return;
    }

    await _fileLibraryService.setRootPath(selected);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('library.rootPath', selected);

    _selectedFolderPath = '';
    _openTabs = const [];
    _activeTabId = null;
    _viewport = const PdfViewportData(
      currentPage: 1,
      totalPages: 1,
      pageText: '',
    );
    _assistantOutput =
        'AI output will appear here. Select a prompt like "Explain this page".';
    _pageAnnotations = const [];
    _lastReadPageByDocumentId = <String, int>{};
    await _saveLastReadPages();

    _libraryRoot = await _fileLibraryService.getRootPath();
    await _reloadLibrary();
    if (mounted) {
      setState(() {
        _section = AppSection.home;
      });
    }
  }

  String get _downloaderRepoPath =>
      '${Directory.current.path}${Platform.pathSeparator}pesu_course_downloader';
  String get _downloaderBridgePath =>
      '$_downloaderRepoPath${Platform.pathSeparator}studypdf_bridge.py';
  String get _downloaderDownloadsPath =>
      '$_downloaderRepoPath${Platform.pathSeparator}downloads';

  String _safeCourseFolderName(String input) {
    final normalized = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    if (normalized.isEmpty) {
      return 'course';
    }
    return normalized;
  }

  Future<String> _resolveDownloaderPythonPath() async {
    final venvPython = File(
      '$_downloaderRepoPath${Platform.pathSeparator}venv'
      '${Platform.pathSeparator}Scripts${Platform.pathSeparator}python.exe',
    );
    if (venvPython.existsSync()) {
      return venvPython.path;
    }
    throw Exception(
      'Downloader environment is not ready. Click "Setup Env" in Downloads first.',
    );
  }

  void _ensureDownloaderRepoReady() {
    final repoDir = Directory(_downloaderRepoPath);
    if (!repoDir.existsSync()) {
      throw Exception(
        'Repository not found at $_downloaderRepoPath. '
        'Keep pesu_course_downloader in project root.',
      );
    }
    final bridge = File(_downloaderBridgePath);
    if (!bridge.existsSync()) {
      throw Exception(
        'Bridge script missing at $_downloaderBridgePath. '
        'Pull latest downloader repo files.',
      );
    }
  }

  Future<Map<String, dynamic>> _runDownloaderBridge(List<String> args) async {
    _ensureDownloaderRepoReady();
    final python = await _resolveDownloaderPythonPath();
    final commandArgs = <String>[_downloaderBridgePath, ...args];
    final result = await Process.run(
      python,
      commandArgs,
      workingDirectory: _downloaderRepoPath,
    );

    final stdout = (result.stdout ?? '').toString().trim();
    final stderr = (result.stderr ?? '').toString().trim();
    final jsonLine = stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.startsWith('{') && line.endsWith('}'))
        .lastWhere((_) => true, orElse: () => '');

    Map<String, dynamic>? payload;
    if (jsonLine.isNotEmpty) {
      final decoded = jsonDecode(jsonLine);
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      }
    }

    if (payload == null) {
      throw Exception(
        'Downloader returned invalid response (exit ${result.exitCode}).\n'
        'STDOUT: $stdout\nSTDERR: $stderr',
      );
    }

    if (payload['ok'] != true) {
      throw Exception(payload['error']?.toString() ?? 'Unknown bridge error');
    }

    if (result.exitCode != 0) {
      throw Exception(
        payload['error']?.toString() ??
            'Downloader failed with exit code ${result.exitCode}',
      );
    }

    return payload;
  }

  Future<void> _runDownloaderSetup() async {
    _ensureDownloaderRepoReady();
    final repoDir = Directory(_downloaderRepoPath);
    final command =
        'if not exist venv\\Scripts\\python.exe (py -3.12 -m venv venv || py -3.11 -m venv venv || python -m venv venv) '
        '&& venv\\Scripts\\python.exe -m pip install --upgrade pip '
        '&& venv\\Scripts\\python.exe -m pip install -r requirements.txt';
    final result = await Process.run('cmd', [
      '/c',
      command,
    ], workingDirectory: repoDir.path);
    if (result.exitCode != 0) {
      throw Exception(
        'Setup failed (exit ${result.exitCode}).\n${result.stderr}',
      );
    }
  }

  void _ensurePesuCredentialsConfigured() {
    if (_pesuUsername.trim().isEmpty || _pesuPassword.isEmpty) {
      throw Exception(
        'Configure PESU username/password in Settings before loading courses.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPesuCourses() async {
    _ensurePesuCredentialsConfigured();
    final payload = await _runDownloaderBridge([
      'courses',
      '--username',
      _pesuUsername.trim(),
      '--password',
      _pesuPassword,
    ]);
    final coursesRaw = payload['courses'];
    if (coursesRaw is! List) {
      return const [];
    }
    return coursesRaw
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _fetchPesuUnits({
    required String courseId,
  }) async {
    _ensurePesuCredentialsConfigured();
    final payload = await _runDownloaderBridge([
      'units',
      '--username',
      _pesuUsername.trim(),
      '--password',
      _pesuPassword,
      '--course-id',
      courseId,
    ]);
    final unitsRaw = payload['units'];
    if (unitsRaw is! List) {
      return const [];
    }
    return unitsRaw
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  Future<String> _runPesuDownload({
    required String courseId,
    required String courseName,
    required List<int> units,
    required List<String> resourceIds,
    required bool convert,
    required bool merge,
    required bool dedup,
    required bool cleanup,
  }) async {
    _ensurePesuCredentialsConfigured();
    final safeCourse = _safeCourseFolderName(courseName);
    final outputDir =
        '$_downloaderDownloadsPath${Platform.pathSeparator}$safeCourse';
    final payload = await _runDownloaderBridge([
      'download',
      '--username',
      _pesuUsername.trim(),
      '--password',
      _pesuPassword,
      '--course-id',
      courseId,
      '--course-name',
      courseName,
      '--units',
      units.join(','),
      '--resources',
      resourceIds.join(','),
      '--output-dir',
      outputDir,
      if (convert) '--convert',
      if (merge) '--merge',
      if (dedup) '--dedup',
      if (cleanup) '--cleanup',
    ]);
    final pdfCount = (payload['pdfCount'] as num?)?.toInt() ?? 0;
    final baseDir = payload['baseDir']?.toString() ?? outputDir;
    return 'Download complete. PDFs: $pdfCount\nSaved to: $baseDir';
  }

  Future<void> _importDownloaderPdfs() async {
    final downloadsDir = Directory(_downloaderDownloadsPath);
    if (!downloadsDir.existsSync()) {
      throw Exception(
        'No downloads folder found yet at $_downloaderDownloadsPath',
      );
    }
    final pdfPaths = downloadsDir
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.toLowerCase().endsWith('.pdf'))
        .toList(growable: false);
    if (pdfPaths.isEmpty) {
      throw Exception(
        'No PDFs found in downloader output.\nExpected under $_downloaderDownloadsPath',
      );
    }

    await _fileLibraryService.importPdfs(
      sourceFilePaths: pdfPaths,
      targetFolderRelativePath: _selectedFolderPath,
    );
    await _reloadLibrary();
    if (mounted) {
      setState(() {
        _section = AppSection.home;
      });
    }
  }

  Future<void> _saveWorkspaceShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workspace.shortcuts',
      WorkspaceShortcut.encodeList(_workspaceShortcuts),
    );
  }

  Future<void> _saveTabColors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workspace.tabColors',
      jsonEncode(_tabColorsByDocumentId),
    );
  }

  Future<void> _saveLastReadPages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workspace.lastReadPages',
      jsonEncode(_lastReadPageByDocumentId),
    );
  }

  void _restoreViewportForActiveDocument() {
    final active = _activeDocument;
    final page = active == null
        ? 1
        : (_lastReadPageByDocumentId[active.id] ?? 1);
    _viewport = PdfViewportData(currentPage: page, totalPages: 1, pageText: '');
  }

  PdfDocument _applyTabColor(PdfDocument doc) {
    final value =
        _tabColorsByDocumentId[doc.id] ?? _tabColorsByDocumentId[doc.path];
    if (value == null) {
      return doc.copyWith(clearTabColor: true);
    }
    return doc.copyWith(tabColorValue: value);
  }

  List<PdfDocument> _applyTabColors(List<PdfDocument> docs) {
    return docs.map(_applyTabColor).toList(growable: false);
  }

  Future<bool> _createWorkspaceShortcut({
    required String name,
    required List<String> tabIds,
    int? colorValue,
  }) async {
    final normalizedName = name.trim().toLowerCase();
    final duplicateByName = _workspaceShortcuts.any(
      (s) => s.name.trim().toLowerCase() == normalizedName,
    );
    if (duplicateByName) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workspace "$name" already exists on Home')),
        );
      }
      return false;
    }
    final shortcut = WorkspaceShortcut(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      tabPaths: tabIds,
      colorValue: colorValue,
    );
    _workspaceShortcuts = [..._workspaceShortcuts, shortcut];
    await _saveWorkspaceShortcuts();
    if (mounted) {
      setState(() {});
    }
    return true;
  }

  Future<void> _openWorkspaceShortcut(WorkspaceShortcut shortcut) async {
    final allDocs = await _fileLibraryService.getDocuments();
    final coloredDocs = _applyTabColors(allDocs);
    final byPath = <String, PdfDocument>{
      for (final doc in coloredDocs) doc.path: doc,
    };
    final docs = shortcut.tabPaths
        .map((path) => byPath[path])
        .whereType<PdfDocument>()
        .toList(growable: false);
    if (docs.isEmpty) {
      return;
    }

    final existingById = {for (final doc in _openTabs) doc.id: doc};
    for (final doc in docs) {
      existingById[doc.id] = doc;
    }
    _openTabs = existingById.values.toList(growable: false);
    _activeTabId = docs.first.id;
    _restoreViewportForActiveDocument();
    _section = AppSection.workspace;
    _shortcutLaunchNonce++;
    _shortcutLaunchRequest = ShortcutLaunchRequest(
      name: shortcut.name,
      tabIds: docs.map((d) => d.id).toList(growable: false),
      nonce: _shortcutLaunchNonce,
      colorValue: shortcut.colorValue,
    );
    _refreshAnnotations();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteWorkspaceShortcutByName(String name) async {
    _workspaceShortcuts = _workspaceShortcuts
        .where((s) => s.name.trim().toLowerCase() != name.trim().toLowerCase())
        .toList(growable: false);
    if (_shortcutLaunchRequest != null &&
        _shortcutLaunchRequest!.name.trim().toLowerCase() ==
            name.trim().toLowerCase()) {
      _shortcutLaunchRequest = null;
    }
    await _saveWorkspaceShortcuts();
    if (mounted) {
      setState(() {});
    }
  }

  void _consumeShortcutLaunch(int nonce) {
    if (_shortcutLaunchRequest == null ||
        _shortcutLaunchRequest!.nonce != nonce) {
      return;
    }
    setState(() {
      _shortcutLaunchRequest = null;
    });
  }

  Future<bool> _renameWorkspaceShortcutByName(
    String oldName,
    String newName,
  ) async {
    final oldNorm = oldName.trim().toLowerCase();
    final newNorm = newName.trim().toLowerCase();
    if (oldNorm == newNorm) {
      return true;
    }

    final index = _workspaceShortcuts.indexWhere(
      (s) => s.name.trim().toLowerCase() == oldNorm,
    );
    if (index == -1) {
      return true;
    }

    final duplicate = _workspaceShortcuts.any(
      (s) =>
          s.name.trim().toLowerCase() == newNorm &&
          s.name.trim().toLowerCase() != oldNorm,
    );
    if (duplicate) {
      return false;
    }

    final current = _workspaceShortcuts[index];
    _workspaceShortcuts[index] = WorkspaceShortcut(
      id: current.id,
      name: newName,
      tabPaths: current.tabPaths,
      colorValue: current.colorValue,
    );
    await _saveWorkspaceShortcuts();
    if (mounted) {
      setState(() {});
    }
    return true;
  }

  Future<void> _syncWorkspaceShortcutByName({
    required String name,
    required List<String> tabIds,
    int? colorValue,
  }) async {
    final norm = name.trim().toLowerCase();
    final index = _workspaceShortcuts.indexWhere(
      (s) => s.name.trim().toLowerCase() == norm,
    );
    if (index == -1) {
      return;
    }
    final current = _workspaceShortcuts[index];
    _workspaceShortcuts[index] = WorkspaceShortcut(
      id: current.id,
      name: current.name,
      tabPaths: tabIds,
      colorValue: colorValue,
    );
    await _saveWorkspaceShortcuts();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _reloadLibrary() async {
    setState(() {
      _loading = true;
    });
    final folders = await _fileLibraryService.getFolders();
    final docs = await _fileLibraryService.getDocuments(
      folderRelativePath: _selectedFolderPath,
    );
    setState(() {
      _folders = folders;
      _documents = _applyTabColors(docs);
      _loading = false;
    });
  }

  Future<void> _selectFolder(String folderPath) async {
    _selectedFolderPath = folderPath;
    await _reloadLibrary();
  }

  Future<void> _createFolder(String folderName, String parentPath) async {
    await _fileLibraryService.createFolder(
      name: folderName,
      parentRelativePath: parentPath,
    );
    await _reloadLibrary();
  }

  Future<void> _importPdfs({String? targetFolderPath}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    final pickedPaths = result?.files
        .map((f) => f.path)
        .whereType<String>()
        .toList(growable: false);
    if (pickedPaths == null || pickedPaths.isEmpty) {
      return;
    }

    await _fileLibraryService.importPdfs(
      sourceFilePaths: pickedPaths,
      targetFolderRelativePath: targetFolderPath ?? _selectedFolderPath,
    );
    await _reloadLibrary();
  }

  Future<void> _deleteDocument(PdfDocument document) async {
    await _fileLibraryService.deleteDocument(document.path);
    _tabColorsByDocumentId.remove(document.id);
    _tabColorsByDocumentId.remove(document.path);
    await _saveTabColors();
    _lastReadPageByDocumentId.remove(document.id);
    _lastReadPageByDocumentId.remove(document.path);
    await _saveLastReadPages();
    _openTabs = _openTabs.where((tab) => tab.id != document.id).toList();
    if (_activeTabId == document.id) {
      _activeTabId = _openTabs.isEmpty ? null : _openTabs.last.id;
    }
    await _reloadLibrary();
    _refreshAnnotations();
    await _broadcastAiState();
    await _broadcastNotesState();
  }

  Future<void> _deleteFolder(String folderPath) async {
    final normalized = folderPath.replaceAll('/', '\\').toLowerCase();
    final absoluteFolderPath =
        '\\${_libraryRoot.replaceAll('/', '\\').toLowerCase()}\\$normalized\\';
    final tabColorKeysToDelete = _tabColorsByDocumentId.keys
        .where(
          (path) => '\\${path.replaceAll('/', '\\').toLowerCase()}\\'
              .startsWith(absoluteFolderPath),
        )
        .toList(growable: false);
    for (final key in tabColorKeysToDelete) {
      _tabColorsByDocumentId.remove(key);
    }
    if (tabColorKeysToDelete.isNotEmpty) {
      await _saveTabColors();
    }
    final pageKeysToDelete = _lastReadPageByDocumentId.keys
        .where(
          (path) => '\\${path.replaceAll('/', '\\').toLowerCase()}\\'
              .startsWith(absoluteFolderPath),
        )
        .toList(growable: false);
    for (final key in pageKeysToDelete) {
      _lastReadPageByDocumentId.remove(key);
    }
    if (pageKeysToDelete.isNotEmpty) {
      await _saveLastReadPages();
    }
    // Remove affected open tabs first so viewer file handles are released.
    _openTabs = _openTabs
        .where(
          (tab) => !tab.folderPath
              .replaceAll('/', '\\')
              .toLowerCase()
              .startsWith(normalized),
        )
        .toList(growable: true);
    if (_openTabs.every((tab) => tab.id != _activeTabId)) {
      _activeTabId = _openTabs.isEmpty ? null : _openTabs.last.id;
    }
    if (_selectedFolderPath.replaceAll('/', '\\').toLowerCase() == normalized) {
      _selectedFolderPath = '';
    }
    if (mounted) {
      setState(() {
        _folders = _folders
            .where(
              (f) =>
                  f.path.isEmpty ||
                  !f.path
                      .replaceAll('/', '\\')
                      .toLowerCase()
                      .startsWith(normalized),
            )
            .toList(growable: false);
      });
    }

    // Give flutter/widgets one frame to detach viewers from soon-to-delete files.
    await Future<void>.delayed(const Duration(milliseconds: 120));

    await _fileLibraryService.deleteFolder(folderPath);
    await _reloadLibrary();
    _refreshAnnotations();
    await _broadcastAiState();
    await _broadcastNotesState();
  }

  Future<bool> _createWorkspaceShortcutFromDocuments(
    String name,
    List<PdfDocument> documents,
  ) async {
    final ok = await _createWorkspaceShortcut(
      name: name,
      tabIds: documents.map((d) => d.path).toList(growable: false),
    );
    if (!ok) {
      return false;
    }

    final existingById = {for (final doc in _openTabs) doc.id: doc};
    final coloredDocs = _applyTabColors(documents);
    for (final doc in coloredDocs) {
      existingById[doc.id] = doc;
    }
    _openTabs = existingById.values.toList(growable: false);
    _activeTabId = coloredDocs.first.id;
    _restoreViewportForActiveDocument();
    _section = AppSection.workspace;
    _shortcutLaunchNonce++;
    _shortcutLaunchRequest = ShortcutLaunchRequest(
      name: name,
      tabIds: coloredDocs.map((d) => d.id).toList(growable: false),
      nonce: _shortcutLaunchNonce,
      colorValue: null,
    );
    _refreshAnnotations();
    if (mounted) {
      setState(() {});
    }
    return true;
  }

  void _openDocument(PdfDocument document) {
    final colored = _applyTabColor(document);
    if (!_openTabs.any((tab) => tab.id == colored.id)) {
      _openTabs = [..._openTabs, colored];
    }
    _activeTabId = colored.id;
    _restoreViewportForActiveDocument();
    _section = AppSection.workspace;
    _refreshAnnotations();
    _broadcastAiState();
    _broadcastNotesState();
    setState(() {});
  }

  void _closeTab(String documentId) {
    _openTabs = _openTabs.where((tab) => tab.id != documentId).toList();
    if (_activeTabId == documentId) {
      _activeTabId = _openTabs.isEmpty ? null : _openTabs.last.id;
      _restoreViewportForActiveDocument();
    }
    _refreshAnnotations();
    _broadcastAiState();
    _broadcastNotesState();
    setState(() {});
  }

  void _switchTab(String documentId) {
    _activeTabId = documentId;
    _restoreViewportForActiveDocument();
    _refreshAnnotations();
    _broadcastAiState();
    _broadcastNotesState();
    setState(() {});
  }

  Future<void> _setTabColor(String documentId, int? colorValue) async {
    if (colorValue == null) {
      _tabColorsByDocumentId.remove(documentId);
    } else {
      _tabColorsByDocumentId[documentId] = colorValue;
    }
    await _saveTabColors();

    if (mounted) {
      setState(() {
        _documents = _documents
            .map(
              (d) => d.id == documentId
                  ? (colorValue == null
                        ? d.copyWith(clearTabColor: true)
                        : d.copyWith(tabColorValue: colorValue))
                  : d,
            )
            .toList(growable: false);
        _openTabs = _openTabs
            .map(
              (d) => d.id == documentId
                  ? (colorValue == null
                        ? d.copyWith(clearTabColor: true)
                        : d.copyWith(tabColorValue: colorValue))
                  : d,
            )
            .toList(growable: false);
      });
    }
  }

  void _onViewportChanged(PdfViewportData viewportData) {
    _viewport = viewportData;
    final active = _activeDocument;
    if (active != null) {
      final previous = _lastReadPageByDocumentId[active.id];
      if (previous != viewportData.currentPage) {
        _lastReadPageByDocumentId[active.id] = viewportData.currentPage;
        _saveLastReadPages();
      }
    }
    _refreshAnnotations();
    _broadcastAiState();
    _broadcastNotesState();
    setState(() {});
  }

  Future<String> _runAssistant({
    required String providerId,
    required String prompt,
  }) async {
    final active = _activeDocument;
    try {
      final currentPage = _viewport.currentPage;
      final currentPageText = _viewport.pageText.trim();
      String ragContext =
          '[Current page p$currentPage]\n${currentPageText.isEmpty ? '(No text extracted for this page.)' : currentPageText}';
      String citationHint = '';
      String webContextBlock = '';
      bool webUsed = false;
      if (active != null) {
        final pageAnchoredQuery = '$prompt\n\n$currentPageText';
        final rag = await _ragService.buildContext(
          pdfPath: active.path,
          query: pageAnchoredQuery,
          topK: 5,
        );
        final secondaryPages = rag.pages
            .where((p) => p != currentPage)
            .toList(growable: false);
        if (rag.context.trim().isNotEmpty) {
          ragContext =
              '$ragContext\n\n---\n\n[Secondary supporting context]\n${rag.context}';
        }
        if (secondaryPages.isNotEmpty) {
          citationHint =
              '\nCurrent page is p$currentPage. Secondary retrieved pages: ${secondaryPages.join(', ')}. Always prioritize current page unless user explicitly asks for other pages.';
        }
      }

      if (_webSearchEnabled &&
          _googleSearchApiKey.trim().isNotEmpty &&
          _googleSearchCx.trim().isNotEmpty) {
        final searchQuery = active == null
            ? prompt
            : '${active.title} ${prompt.trim()}';
        final web = await _googleSearchService.search(
          query: searchQuery,
          apiKey: _googleSearchApiKey,
          searchEngineId: _googleSearchCx,
          maxResults: 3,
        );
        if (web.context.trim().isNotEmpty) {
          webUsed = true;
          webContextBlock =
              '\n\n[Web search snippets]\n${web.context}\n\nSources:\n${web.sources.join('\n')}';
          citationHint =
              '$citationHint\nWeb snippets are available; use them for missing definitions and cite as [web1], [web2], etc.';
        }
      }

      final combinedContext = '$ragContext$webContextBlock';

      final guidedPrompt =
          '''
$prompt

You are answering about the CURRENTLY VISIBLE PDF PAGE: p$currentPage.
Use "[Current page p$currentPage]" as primary source of truth.
Use secondary context only for support.
Use web snippets only to fill missing definitions or background.
If there is a conflict, trust current page.
If current page context is insufficient, say exactly what is missing.
If web snippets are present, cite them as [web1], [web2], etc.
$citationHint
''';

      final provider = _providerRegistry.resolve(providerId);
      final response = await provider.sendPrompt(
        prompt: guidedPrompt,
        context: combinedContext,
        apiKey: switch (providerId) {
          'openai' => _openAiApiKey,
          'groq' => _groqApiKey,
          'gemini' => _geminiApiKey,
          _ => null,
        },
      );
      _assistantOutput = response;
      await _broadcastAiState();
      setState(() {});
      if (_webSearchEnabled &&
          _googleSearchApiKey.trim().isNotEmpty &&
          _googleSearchCx.trim().isNotEmpty &&
          !webUsed) {
        return '$response\n\n_Note: Web fallback is enabled but no web snippets were retrieved for this query._';
      }
      return response;
    } catch (e) {
      _assistantOutput = 'AI request failed:\n${e.toString()}';
      await _broadcastAiState();
      setState(() {});
      return _assistantOutput;
    }
  }

  Future<void> _openExternalAiWindow() async {
    final active = _activeDocument;
    if (active == null) {
      return;
    }
    final payload = jsonEncode({
      'panel': 'ai',
      'documentId': active.id,
      'documentTitle': active.title,
      'pageNumber': _viewport.currentPage,
      'pageText': _viewport.pageText,
      'assistantOutput': _assistantOutput,
    });

    final window = await DesktopMultiWindow.createWindow(payload);
    _externalAiWindowIds.add(window.windowId);
    window
      ..setFrame(const Offset(120, 120) & const Size(520, 760))
      ..setTitle('StudyPDF - AI Assistant')
      ..show();
  }

  Future<void> _openExternalNotesWindow() async {
    final active = _activeDocument;
    if (active == null) {
      return;
    }
    final payload = jsonEncode({
      'panel': 'notes',
      'documentId': active.id,
      'documentTitle': active.title,
      'pageNumber': _viewport.currentPage,
      'annotations': _pageAnnotations
          .map(
            (a) => {
              'id': a.id,
              'pdfId': a.pdfId,
              'pageNumber': a.pageNumber,
              'content': a.content,
              'createdAt': a.createdAt.toIso8601String(),
            },
          )
          .toList(),
    });

    final window = await DesktopMultiWindow.createWindow(payload);
    _externalNotesWindowIds.add(window.windowId);
    window
      ..setFrame(const Offset(180, 180) & const Size(700, 760))
      ..setTitle('StudyPDF - Notes')
      ..show();
  }

  void _saveAnnotation(String text) {
    final activeDocument = _activeDocument;
    if (activeDocument == null || text.trim().isEmpty) {
      return;
    }

    _store.addAnnotation(
      Annotation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        pdfId: activeDocument.id,
        pageNumber: _viewport.currentPage,
        content: text.trim(),
        createdAt: DateTime.now(),
      ),
    );

    _refreshAnnotations();
    _broadcastNotesState();
    setState(() {});
  }

  void _refreshAnnotations() {
    final activeDocument = _activeDocument;
    if (activeDocument == null) {
      _pageAnnotations = const [];
      return;
    }
    _pageAnnotations = _store.getAnnotations(
      pdfId: activeDocument.id,
      page: _viewport.currentPage,
    );
  }

  List<Map<String, dynamic>> _serializedAnnotations() {
    return _pageAnnotations
        .map(
          (a) => {
            'id': a.id,
            'pdfId': a.pdfId,
            'pageNumber': a.pageNumber,
            'content': a.content,
            'createdAt': a.createdAt.toIso8601String(),
          },
        )
        .toList(growable: false);
  }

  Future<void> _broadcastAiState() async {
    for (final id in _externalAiWindowIds.toList(growable: false)) {
      await _pushAiStateToWindow(id);
    }
  }

  Future<void> _broadcastNotesState() async {
    for (final id in _externalNotesWindowIds.toList(growable: false)) {
      await _pushNotesStateToWindow(id);
    }
  }

  Future<void> _pushAiStateToWindow(int id) async {
    try {
      await DesktopMultiWindow.invokeMethod(id, 'mainStateUpdated', {
        'panel': 'ai',
        'documentId': _activeDocument?.id,
        'documentTitle': _activeDocument?.title,
        'pageNumber': _viewport.currentPage,
        'pageText': _viewport.pageText,
        'assistantOutput': _assistantOutput,
      });
    } catch (_) {
      _externalAiWindowIds.remove(id);
    }
  }

  Future<void> _pushNotesStateToWindow(int id) async {
    try {
      await DesktopMultiWindow.invokeMethod(id, 'mainStateUpdated', {
        'panel': 'notes',
        'documentId': _activeDocument?.id,
        'documentTitle': _activeDocument?.title,
        'pageNumber': _viewport.currentPage,
        'annotations': _serializedAnnotations(),
      });
    } catch (_) {
      _externalNotesWindowIds.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredDocs = _documents
        .where(
          (doc) => _query.trim().isEmpty
              ? true
              : doc.title.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList(growable: false);
    final recentDocs = List<PdfDocument>.from(_documents)
      ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));

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
              _importPdfs(targetFolderPath: _selectedFolderPath);
              return null;
            },
          ),
          NewTabIntent: CallbackAction<NewTabIntent>(
            onInvoke: (_) {
              setState(() {
                _section = AppSection.home;
              });
              return null;
            },
          ),
          ExplainPageIntent: CallbackAction<ExplainPageIntent>(
            onInvoke: (_) {
              _runAssistant(
                providerId: _defaultAiProviderId,
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
                  setState(() {
                    _section = AppSection.home;
                  });
                },
                icon: const Icon(Icons.home_outlined),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _section.index,
                onDestinationSelected: (index) {
                  setState(() {
                    _section = AppSection.values[index];
                  });
                },
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.folder_open_outlined),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.picture_as_pdf_outlined),
                    label: Text('Workspace'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.download_outlined),
                    label: Text('Downloads'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    label: Text('Settings'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : IndexedStack(
                        index: _section.index,
                        children: [
                          DocumentLibraryPage(
                            documents: filteredDocs,
                            recentDocuments: recentDocs.take(5).toList(),
                            folders: _folders,
                            shortcuts: _workspaceShortcuts,
                            selectedFolderPath: _selectedFolderPath,
                            libraryRoot: _libraryRoot,
                            onSelectFolder: _selectFolder,
                            onCreateFolder: _createFolder,
                            onImportPdf: (targetFolder) =>
                                _importPdfs(targetFolderPath: targetFolder),
                            onDeleteDocument: _deleteDocument,
                            onDeleteFolder: _deleteFolder,
                            onOpenDocument: _openDocument,
                            onOpenShortcut: _openWorkspaceShortcut,
                            onCreateWorkspaceFromDocuments:
                                _createWorkspaceShortcutFromDocuments,
                          ),
                          StudyWorkspacePage(
                            openTabs: _openTabs,
                            activeTabId: _activeTabId,
                            viewportData: _viewport,
                            pageAnnotations: _pageAnnotations,
                            assistantOutput: _assistantOutput,
                            providers: _providerRegistry.all,
                            onTabSelected: _switchTab,
                            onCloseTab: _closeTab,
                            onTabColorChanged: _setTabColor,
                            onViewportChanged: _onViewportChanged,
                            onRunPrompt: _runAssistant,
                            onSaveNote: _saveAnnotation,
                            activeDocument: _activeDocument,
                            onOpenExternalAiWindow: _openExternalAiWindow,
                            onOpenExternalNotesWindow: _openExternalNotesWindow,
                            notesOrientation:
                                _workspacePreferences.notesOrientation,
                            defaultAiVisible:
                                _workspacePreferences.startWithAiVisible,
                            defaultNotesVisible:
                                _workspacePreferences.startWithNotesVisible,
                            defaultAiProviderId: _defaultAiProviderId,
                            onCreateHomeShortcut: _createWorkspaceShortcut,
                            onDeleteHomeShortcutByName:
                                _deleteWorkspaceShortcutByName,
                            onRenameHomeShortcutByName:
                                _renameWorkspaceShortcutByName,
                            onSyncHomeShortcutByName:
                                _syncWorkspaceShortcutByName,
                            shortcutLaunchRequest: _shortcutLaunchRequest,
                            onShortcutLaunchConsumed: _consumeShortcutLaunch,
                          ),
                          PesuDownloaderPage(
                            downloadsPath: _downloaderDownloadsPath,
                            credentialsConfigured:
                                _pesuUsername.trim().isNotEmpty &&
                                _pesuPassword.isNotEmpty,
                            onSetupEnvironment: _runDownloaderSetup,
                            onFetchCourses: _fetchPesuCourses,
                            onFetchUnits: _fetchPesuUnits,
                            onRunDownload: _runPesuDownload,
                            onImportDownloads: _importDownloaderPdfs,
                          ),
                          WorkspaceSettingsPage(
                            preferences: _workspacePreferences,
                            onChanged: _updateWorkspacePreferences,
                            themeMode: _themeMode,
                            onThemeModeChanged: _updateThemeMode,
                            libraryRoot: _libraryRoot,
                            onChangeLibraryRoot: _changeLibraryRoot,
                            openAiApiKey: _openAiApiKey,
                            groqApiKey: _groqApiKey,
                            geminiApiKey: _geminiApiKey,
                            onApiKeyChanged: _updateApiKey,
                            webSearchEnabled: _webSearchEnabled,
                            googleSearchApiKey: _googleSearchApiKey,
                            googleSearchEngineId: _googleSearchCx,
                            onWebSearchSettingsChanged:
                                _updateWebSearchSettings,
                            defaultAiProviderId: _defaultAiProviderId,
                            onDefaultAiProviderChanged:
                                _updateDefaultAiProvider,
                            pesuUsername: _pesuUsername,
                            pesuPassword: _pesuPassword,
                            onPesuCredentialsChanged: _updatePesuCredentials,
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
