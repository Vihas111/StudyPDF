import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studypdf/core/ai/ai_provider_registry.dart';
import 'package:studypdf/core/ai/ocr_service.dart';
import 'package:studypdf/core/ai/providers/openrouter_provider.dart';
import 'package:studypdf/core/ai/rag/google_search_service.dart';
import 'package:studypdf/core/ai/rag/pdf_rag_service.dart';
import 'package:studypdf/core/state/workspace_controller.dart';

/// Holds AI-provider settings, web-search/RAG settings, PESU downloader
/// credentials/bridge orchestration, and assistant output — extracted from
/// `_StudyShellPageState` in `lib/app.dart` (Phase 0 refactor).
///
/// The `_runAssistant` orchestration needs read access to the active
/// document/viewport/open-tab state, which now lives in
/// [WorkspaceController]; that dependency is passed in via the
/// constructor (composition, not inheritance) rather than duplicated here.
class AiSettingsController extends ChangeNotifier {
  AiSettingsController({required this.workspace});

  final WorkspaceController workspace;

  final AIProviderRegistry providerRegistry = AIProviderRegistry();
  final GoogleSearchService googleSearchService = GoogleSearchService();
  final PdfRagService ragService = PdfRagService();
  final OcrService ocrService = OcrService();

  /// Called after assistant output or the active provider changes, so any
  /// open pop-out AI window gets the update. Wired up by `WindowController`.
  Future<void> Function()? onAiStateShouldBroadcast;

  String openAiApiKey = '';
  String groqApiKey = '';
  String geminiApiKey = '';
  String openRouterApiKey = '';
  String openRouterModelId = openRouterDefaultModel;
  List<OpenRouterFreeModel> openRouterFreeModels = const [];
  bool openRouterFreeModelsLoading = false;
  String defaultAiProviderId = 'openrouter';
  String activeAiProviderId = 'openrouter';
  bool webSearchEnabled = false;
  bool crossDocRagEnabled = false;
  String googleSearchApiKey = '';
  String googleSearchCx = '';
  String pesuUsername = '';
  String pesuPassword = '';

  String assistantOutput =
      'AI output will appear here. Select a prompt like "Explain this page".';

  /// Public wrapper so `WindowController` (which mutates fields here
  /// directly while handling multi-window callbacks) can trigger a
  /// rebuild without reaching into the protected [notifyListeners] API.
  void notifyChanged() => notifyListeners();

  Future<void> _broadcastAi() async {
    final cb = onAiStateShouldBroadcast;
    if (cb != null) {
      await cb();
    }
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    openAiApiKey = prefs.getString('ai.openaiApiKey') ?? '';
    groqApiKey =
        prefs.getString('ai.groqApiKey') ??
        prefs.getString('ai.anthropicApiKey') ??
        '';
    geminiApiKey = prefs.getString('ai.geminiApiKey') ?? '';
    openRouterApiKey = prefs.getString('ai.openrouterApiKey') ?? '';
    openRouterModelId =
        prefs.getString('ai.openrouterModelId') ?? openRouterDefaultModel;
    final rawDefault = prefs.getString('ai.defaultProviderId') ?? 'openrouter';
    defaultAiProviderId = rawDefault == 'anthropic' ? 'groq' : rawDefault;
    activeAiProviderId = defaultAiProviderId;
    webSearchEnabled = prefs.getBool('ai.webSearchEnabled') ?? false;
    crossDocRagEnabled = prefs.getBool('ai.crossDocRagEnabled') ?? false;
    googleSearchApiKey = prefs.getString('ai.googleSearchApiKey') ?? '';
    googleSearchCx = prefs.getString('ai.googleSearchEngineId') ?? '';
    pesuUsername = prefs.getString('pesu.username') ?? '';
    pesuPassword = prefs.getString('pesu.password') ?? '';
  }

  Future<void> updateApiKey({
    required String providerId,
    required String key,
  }) async {
    final trimmed = key.trim();
    final prefs = await SharedPreferences.getInstance();
    final prefKey = switch (providerId) {
      'openai' => 'ai.openaiApiKey',
      'groq' => 'ai.groqApiKey',
      'gemini' => 'ai.geminiApiKey',
      'openrouter' => 'ai.openrouterApiKey',
      _ => '',
    };
    if (prefKey.isEmpty) {
      return;
    }
    await prefs.setString(prefKey, trimmed);
    switch (providerId) {
      case 'openai':
        openAiApiKey = trimmed;
        break;
      case 'groq':
        groqApiKey = trimmed;
        break;
      case 'gemini':
        geminiApiKey = trimmed;
        break;
      case 'openrouter':
        openRouterApiKey = trimmed;
        break;
      default:
        break;
    }
    notifyListeners();
  }

  Future<void> updateOpenRouterModel(String modelId) async {
    final trimmed = modelId.trim();
    if (trimmed.isEmpty || trimmed == openRouterModelId) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai.openrouterModelId', trimmed);
    openRouterModelId = trimmed;
    notifyListeners();
  }

  /// Fetches OpenRouter's current free-model catalog for the Settings
  /// dropdown. Safe to call repeatedly (e.g. a manual refresh button) —
  /// [OpenRouterProvider.fetchFreeModels] never throws.
  Future<void> loadOpenRouterFreeModels() async {
    openRouterFreeModelsLoading = true;
    notifyListeners();
    final provider = providerRegistry.resolve('openrouter');
    if (provider is OpenRouterProvider) {
      openRouterFreeModels = await provider.fetchFreeModels();
    }
    openRouterFreeModelsLoading = false;
    notifyListeners();
  }

  Future<void> updateWebSearchSettings({
    required bool enabled,
    required String apiKey,
    required String searchEngineId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai.webSearchEnabled', enabled);
    await prefs.setString('ai.googleSearchApiKey', apiKey.trim());
    await prefs.setString('ai.googleSearchEngineId', searchEngineId.trim());
    webSearchEnabled = enabled;
    googleSearchApiKey = apiKey.trim();
    googleSearchCx = searchEngineId.trim();
    notifyListeners();
  }

  Future<void> updateCrossDocRagEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai.crossDocRagEnabled', enabled);
    crossDocRagEnabled = enabled;
    notifyListeners();
  }

  Future<void> updateDefaultAiProvider(String providerId) async {
    final allowed = {'openrouter', 'openai', 'groq', 'gemini', 'ollama'};
    if (!allowed.contains(providerId)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai.defaultProviderId', providerId);
    defaultAiProviderId = providerId;
    activeAiProviderId = providerId;
    notifyListeners();
  }

  void handleAiProviderChanged(String providerId) {
    if (activeAiProviderId == providerId) {
      return;
    }
    activeAiProviderId = providerId;
    notifyListeners();
    _broadcastAi();
  }

  Future<void> updatePesuCredentials({
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pesu.username', username.trim());
    await prefs.setString('pesu.password', password);
    pesuUsername = username.trim();
    pesuPassword = password;
    notifyListeners();
  }

  String get downloaderRepoPath =>
      '${Directory.current.path}${Platform.pathSeparator}pesu_course_downloader';
  String get downloaderBridgePath =>
      '$downloaderRepoPath${Platform.pathSeparator}studypdf_bridge.py';
  String get downloaderDownloadsPath =>
      '$downloaderRepoPath${Platform.pathSeparator}downloads';

  String safeCourseFolderName(String input) {
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

  Future<String> resolveDownloaderPythonPath() async {
    final venvPython = File(
      '$downloaderRepoPath${Platform.pathSeparator}venv'
      '${Platform.pathSeparator}Scripts${Platform.pathSeparator}python.exe',
    );
    if (venvPython.existsSync()) {
      return venvPython.path;
    }
    throw Exception(
      'Downloader environment is not ready. Click "Setup Env" in Downloads first.',
    );
  }

  void ensureDownloaderRepoReady() {
    final repoDir = Directory(downloaderRepoPath);
    if (!repoDir.existsSync()) {
      throw Exception(
        'Repository not found at $downloaderRepoPath. '
        'Keep pesu_course_downloader in project root.',
      );
    }
    final bridge = File(downloaderBridgePath);
    if (!bridge.existsSync()) {
      throw Exception(
        'Bridge script missing at $downloaderBridgePath. '
        'Pull latest downloader repo files.',
      );
    }
  }

  Future<Map<String, dynamic>> runDownloaderBridge(List<String> args) async {
    ensureDownloaderRepoReady();
    final python = await resolveDownloaderPythonPath();
    final commandArgs = <String>[downloaderBridgePath, ...args];
    final result = await Process.run(
      python,
      commandArgs,
      workingDirectory: downloaderRepoPath,
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

  Future<void> runDownloaderSetup() async {
    ensureDownloaderRepoReady();
    final repoDir = Directory(downloaderRepoPath);
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

  void ensurePesuCredentialsConfigured() {
    if (pesuUsername.trim().isEmpty || pesuPassword.isEmpty) {
      throw Exception(
        'Configure PESU username/password in Settings before loading courses.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchPesuCourses() async {
    ensurePesuCredentialsConfigured();
    final payload = await runDownloaderBridge([
      'courses',
      '--username',
      pesuUsername.trim(),
      '--password',
      pesuPassword,
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

  Future<List<Map<String, dynamic>>> fetchPesuUnits({
    required String courseId,
  }) async {
    ensurePesuCredentialsConfigured();
    final payload = await runDownloaderBridge([
      'units',
      '--username',
      pesuUsername.trim(),
      '--password',
      pesuPassword,
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

  Future<String> runPesuDownload({
    required String courseId,
    required String courseName,
    required List<int> units,
    required List<String> resourceIds,
    required bool convert,
    required bool merge,
    required bool dedup,
    required bool cleanup,
  }) async {
    ensurePesuCredentialsConfigured();
    final safeCourse = safeCourseFolderName(courseName);
    final outputDir =
        '$downloaderDownloadsPath${Platform.pathSeparator}$safeCourse';
    final payload = await runDownloaderBridge([
      'download',
      '--username',
      pesuUsername.trim(),
      '--password',
      pesuPassword,
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

  Future<String> runAssistant({
    required String providerId,
    required String prompt,
  }) async {
    final active = workspace.activeDocument;
    try {
      if (providerId != activeAiProviderId) {
        activeAiProviderId = providerId;
      }
      final currentPage = workspace.viewport.currentPage;
      final currentPageText = workspace.viewport.pageText.trim();
      String ragContext =
          '[Current page p$currentPage]\n${currentPageText.isEmpty ? '(No text extracted for this page.)' : currentPageText}';
      String citationHint = '';
      String webContextBlock = '';
      bool webUsed = false;
      if (crossDocRagEnabled && workspace.openTabs.isNotEmpty) {
        final pageAnchoredQuery = '$prompt\n\n$currentPageText';
        final futures = workspace.openTabs.map(
          (tab) => ragService.buildContext(
            pdfPath: tab.path,
            query: pageAnchoredQuery,
            topK: 3, // slightly fewer per-doc since we're merging many
          ),
        );
        final results = await Future.wait(futures);

        // Merge and re-rank all retrieved chunks globally
        for (int i = 0; i < workspace.openTabs.length; i++) {
          final tab = workspace.openTabs[i];
          final res = results[i];
          // We hackily extract the chunks and scores from the formatted string,
          // or we can just append them all with Doc markers. The RAG service
          // returns a block string. Let's just combine the result strings for now,
          // prepending the document title.
          if (res.context.trim().isNotEmpty) {
            final docContext = res.context
                .split('\n\n---\n\n')
                .where((c) => c.trim().isNotEmpty)
                .map((c) => '[Doc: ${tab.title}] $c')
                .join('\n\n---\n\n');
            ragContext = '$ragContext\n\n---\n\n$docContext';
          }
        }
        citationHint =
            '\nCurrent page is p$currentPage. You have cross-document RAG enabled. Citations include [Doc: title] [Page N]. Always prioritize current page unless user explicitly asks for other pages.';
      } else if (active != null) {
        final pageAnchoredQuery = '$prompt\n\n$currentPageText';
        final rag = await ragService.buildContext(
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

      if (webSearchEnabled &&
          googleSearchApiKey.trim().isNotEmpty &&
          googleSearchCx.trim().isNotEmpty) {
        final searchQuery = active == null
            ? prompt
            : '${active.title} ${prompt.trim()}';
        final web = await googleSearchService.search(
          query: searchQuery,
          apiKey: googleSearchApiKey,
          searchEngineId: googleSearchCx,
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

      final provider = providerRegistry.resolve(providerId);
      final response = await provider.sendPrompt(
        prompt: guidedPrompt,
        context: combinedContext,
        apiKey: switch (providerId) {
          'openai' => openAiApiKey,
          'groq' => groqApiKey,
          'gemini' => geminiApiKey,
          'openrouter' => openRouterApiKey,
          _ => null,
        },
        model: providerId == 'openrouter' ? openRouterModelId : null,
      );
      assistantOutput = response;
      await _broadcastAi();
      notifyListeners();
      if (webSearchEnabled &&
          googleSearchApiKey.trim().isNotEmpty &&
          googleSearchCx.trim().isNotEmpty &&
          !webUsed) {
        return '$response\n\n_Note: Web fallback is enabled but no web snippets were retrieved for this query._';
      }
      return response;
    } catch (e) {
      assistantOutput = 'AI request failed:\n${e.toString()}';
      await _broadcastAi();
      notifyListeners();
      return assistantOutput;
    }
  }

  Future<HandwritingTranscription> transcribeHandwriting({
    required Uint8List imageBytes,
    required String mimeType,
  }) {
    return ocrService.transcribeHandwriting(
      imageBytes: imageBytes,
      apiKey: openRouterApiKey,
      mimeType: mimeType,
    );
  }
}
