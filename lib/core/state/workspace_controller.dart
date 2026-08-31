import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studypdf/core/storage/file_library_service.dart';
import 'package:studypdf/core/storage/local_store.dart';
import 'package:studypdf/core/storage/merged_notes_store.dart';
import 'package:studypdf/core/storage/note_assets_store.dart';
import 'package:studypdf/core/storage/rich_notes_store.dart';
import 'package:studypdf/core/utils/slug.dart';
import 'package:studypdf/models/annotation.dart';
import 'package:studypdf/models/library_folder.dart';
import 'package:studypdf/models/merged_note.dart';
import 'package:studypdf/models/pdf_document.dart';
import 'package:studypdf/models/pdf_viewport_data.dart';
import 'package:studypdf/models/workspace_preferences.dart';
import 'package:studypdf/models/workspace_shortcut.dart';

/// AppSection lives here since it's the workspace's top-level navigation
/// state (which section/screen is currently showing).
enum AppSection { home, workspace, downloader, notes, settings }

/// Holds open-tab/document-library/panel-docking/notes state that used to
/// live directly on `_StudyShellPageState` in `lib/app.dart`.
///
/// This is a behavior-preserving extraction (Phase 0 of the roadmap) — the
/// logic below is unchanged from the original god-object methods, just
/// moved here and using [notifyListeners] instead of `setState`.
class WorkspaceController extends ChangeNotifier {
  final LocalStore store = LocalStore();
  final RichNotesStore richNotesStore = RichNotesStore();
  final MergedNotesStore mergedNotesStore = MergedNotesStore();
  final FileLibraryService fileLibraryService = FileLibraryService();
  final NoteAssetsStore noteAssetsStore = NoteAssetsStore();

  Future<String> saveNoteImage({
    required Uint8List bytes,
    required String extension,
  }) {
    return noteAssetsStore.saveImage(
      libraryRoot: libraryRoot,
      bytes: bytes,
      extension: extension,
    );
  }

  /// Called after actions that should push updated AI state to any open
  /// pop-out AI window. Wired up by `WindowController` from the
  /// composition root.
  Future<void> Function()? onAiStateShouldBroadcast;

  /// Called after actions that should push updated notes state to any open
  /// pop-out Notes window.
  Future<void> Function()? onNotesStateShouldBroadcast;

  AppSection section = AppSection.home;
  String query = '';
  String selectedFolderPath = '';
  bool loading = true;
  String libraryRoot = '';
  WorkspacePreferences workspacePreferences = const WorkspacePreferences();
  ThemeMode themeMode = ThemeMode.system;

  /// 'piston' (free, external — default) or 'local' (desktop-only, opt-in;
  /// runs code via whatever interpreters/compilers are installed on the
  /// user's machine, so it stays private but requires those toolchains).
  String codeExecutionBackend = 'piston';
  List<WorkspaceShortcut> workspaceShortcuts = const [];
  Map<String, int> tabColorsByDocumentId = <String, int>{};
  Map<String, int> lastReadPageByDocumentId = <String, int>{};
  ShortcutLaunchRequest? shortcutLaunchRequest;
  int shortcutLaunchNonce = 0;

  List<PdfDocument> documents = [];
  List<LibraryFolder> folders = [];
  List<PdfDocument> openTabs = [];
  String? activeTabId;
  PdfViewportData viewport = const PdfViewportData(
    currentPage: 1,
    totalPages: 1,
    pageText: '',
  );

  List<Annotation> pageAnnotations = const [];

  /// Public wrapper so sibling controllers (e.g. `WindowController`, which
  /// mutates fields here directly while handling multi-window callbacks)
  /// can trigger a rebuild without reaching into the protected
  /// [notifyListeners] API.
  void notifyChanged() => notifyListeners();

  PdfDocument? get activeDocument {
    if (activeTabId == null) {
      return null;
    }
    for (final doc in openTabs) {
      if (doc.id == activeTabId) {
        return doc;
      }
    }
    return null;
  }

  Future<void> _broadcastAi() async {
    final cb = onAiStateShouldBroadcast;
    if (cb != null) {
      await cb();
    }
  }

  Future<void> _broadcastNotes() async {
    final cb = onNotesStateShouldBroadcast;
    if (cb != null) {
      await cb();
    }
  }

  Future<void> initialize() async {
    await richNotesStore.load();
    await mergedNotesStore.load();
    await loadPreferences();
    libraryRoot = await fileLibraryService.getRootPath();
    await reloadLibrary();
    await pruneDeadWorkspaceShortcuts();
  }

  /// Drops shortcut tab entries that no longer point at a file on disk
  /// (e.g. the document was deleted outside a flow that already prunes
  /// shortcuts, or the shortcuts list was carried over from before pruning
  /// existed). A shortcut left with zero valid tabs is removed entirely.
  /// Runs once at startup to self-heal any already-broken data; ongoing
  /// deletions are pruned immediately by [deleteDocument]/[deleteFolder].
  Future<void> pruneDeadWorkspaceShortcuts() async {
    if (workspaceShortcuts.isEmpty) {
      return;
    }
    final allDocs = await fileLibraryService.getDocuments();
    final validPaths = allDocs.map((d) => d.path).toSet();
    await _pruneWorkspaceShortcuts(
      isValidPath: (path) => validPaths.contains(path),
    );
  }

  /// Shared implementation for dropping stale shortcut tab paths.
  /// [isValidPath] decides whether a given tab path should be kept.
  Future<void> _pruneWorkspaceShortcuts({
    required bool Function(String path) isValidPath,
  }) async {
    var changed = false;
    final survivors = <WorkspaceShortcut>[];
    for (final shortcut in workspaceShortcuts) {
      final keptPaths = shortcut.tabPaths
          .where(isValidPath)
          .toList(growable: false);
      if (keptPaths.length != shortcut.tabPaths.length) {
        changed = true;
      }
      if (keptPaths.isEmpty) {
        changed = true;
        continue;
      }
      survivors.add(
        keptPaths.length == shortcut.tabPaths.length
            ? shortcut
            : WorkspaceShortcut(
                id: shortcut.id,
                name: shortcut.name,
                tabPaths: keptPaths,
                colorValue: shortcut.colorValue,
              ),
      );
    }
    if (!changed) {
      return;
    }
    workspaceShortcuts = survivors;
    await saveWorkspaceShortcuts();
    notifyListeners();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeRaw = prefs.getString('app.themeMode') ?? 'system';
    themeMode = themeModeFromString(themeRaw);

    final customRoot = prefs.getString('library.rootPath');
    if (customRoot != null && customRoot.trim().isNotEmpty) {
      await fileLibraryService.setRootPath(customRoot);
    }

    codeExecutionBackend = prefs.getString('code.executionBackend') ?? 'piston';

    final legacyNotesOrientation =
        prefs.getString('workspace.notesOrientation') ?? 'bottom';
    final aiDockRaw = prefs.getString('workspace.aiDockPosition') ?? 'right';
    final notesDockRaw =
        prefs.getString('workspace.notesDockPosition') ??
        (legacyNotesOrientation == 'right' ? 'right' : 'bottom');
    final startAi = prefs.getBool('workspace.startWithAiVisible') ?? true;
    final startNotes = prefs.getBool('workspace.startWithNotesVisible') ?? true;
    final enablePesu = prefs.getBool('workspace.enablePesuDownloader') ?? false;

    workspacePreferences = WorkspacePreferences(
      aiDockPosition: panelDockPositionFromRaw(aiDockRaw),
      notesDockPosition: panelDockPositionFromRaw(notesDockRaw),
      startWithAiVisible: startAi,
      startWithNotesVisible: startNotes,
      enablePesuDownloader: enablePesu,
    );

    final shortcutsRaw = prefs.getString('workspace.shortcuts');
    if (shortcutsRaw != null && shortcutsRaw.trim().isNotEmpty) {
      try {
        workspaceShortcuts = WorkspaceShortcut.decodeList(shortcutsRaw);
      } catch (_) {
        workspaceShortcuts = const [];
      }
    } else {
      workspaceShortcuts = const [];
    }

    final tabColorsRaw = prefs.getString('workspace.tabColors');
    if (tabColorsRaw != null && tabColorsRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(tabColorsRaw);
        if (decoded is Map<String, dynamic>) {
          tabColorsByDocumentId = decoded.map(
            (key, value) => MapEntry(key, value as int),
          );
        } else {
          tabColorsByDocumentId = <String, int>{};
        }
      } catch (_) {
        tabColorsByDocumentId = <String, int>{};
      }
    } else {
      tabColorsByDocumentId = <String, int>{};
    }

    final lastPagesRaw = prefs.getString('workspace.lastReadPages');
    if (lastPagesRaw != null && lastPagesRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(lastPagesRaw);
        if (decoded is Map<String, dynamic>) {
          lastReadPageByDocumentId = decoded.map(
            (key, value) => MapEntry(key, (value as num).toInt()),
          );
        } else {
          lastReadPageByDocumentId = <String, int>{};
        }
      } catch (_) {
        lastReadPageByDocumentId = <String, int>{};
      }
    } else {
      lastReadPageByDocumentId = <String, int>{};
    }
  }

  Future<void> updateCodeExecutionBackend(String backend) async {
    if (backend != 'piston' && backend != 'local') {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('code.executionBackend', backend);
    codeExecutionBackend = backend;
    notifyListeners();
  }

  Future<void> updateWorkspacePreferences(WorkspacePreferences updated) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workspace.aiDockPosition',
      panelDockPositionToRaw(updated.aiDockPosition),
    );
    await prefs.setString(
      'workspace.notesDockPosition',
      panelDockPositionToRaw(updated.notesDockPosition),
    );
    await prefs.setBool(
      'workspace.startWithAiVisible',
      updated.startWithAiVisible,
    );
    await prefs.setBool(
      'workspace.startWithNotesVisible',
      updated.startWithNotesVisible,
    );
    await prefs.setBool(
      'workspace.enablePesuDownloader',
      updated.enablePesuDownloader,
    );

    workspacePreferences = updated;
    // The Downloads nav destination disappears once disabled — if that's
    // where the user currently is, there's nothing left to show there.
    if (!updated.enablePesuDownloader && section == AppSection.downloader) {
      section = AppSection.home;
    }
    notifyListeners();
  }

  PanelDockPosition panelDockPositionFromRaw(String raw) {
    switch (raw) {
      case 'left':
        return PanelDockPosition.left;
      case 'bottom':
        return PanelDockPosition.bottom;
      case 'right':
      default:
        return PanelDockPosition.right;
    }
  }

  String panelDockPositionToRaw(PanelDockPosition value) {
    switch (value) {
      case PanelDockPosition.left:
        return 'left';
      case PanelDockPosition.bottom:
        return 'bottom';
      case PanelDockPosition.right:
        return 'right';
    }
  }

  ThemeMode themeModeFromString(String raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> updateThemeMode(
    ThemeMode mode,
    ValueChanged<ThemeMode> onThemeModeChanged,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app.themeMode', themeModeToString(mode));
    themeMode = mode;
    notifyListeners();
    onThemeModeChanged(mode);
  }

  Future<void> changeLibraryRoot() async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose StudyPDF Library Root',
    );
    if (selected == null || selected.trim().isEmpty) {
      return;
    }

    await fileLibraryService.setRootPath(selected);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('library.rootPath', selected);

    selectedFolderPath = '';
    openTabs = const [];
    activeTabId = null;
    viewport = const PdfViewportData(
      currentPage: 1,
      totalPages: 1,
      pageText: '',
    );
    pageAnnotations = const [];
    lastReadPageByDocumentId = <String, int>{};
    await saveLastReadPages();

    libraryRoot = await fileLibraryService.getRootPath();
    await reloadLibrary();
    section = AppSection.home;
    notifyListeners();
  }

  Future<void> saveWorkspaceShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workspace.shortcuts',
      WorkspaceShortcut.encodeList(workspaceShortcuts),
    );
  }

  Future<void> saveTabColors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workspace.tabColors',
      jsonEncode(tabColorsByDocumentId),
    );
  }

  Future<void> saveLastReadPages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workspace.lastReadPages',
      jsonEncode(lastReadPageByDocumentId),
    );
  }

  void restoreViewportForActiveDocument() {
    final active = activeDocument;
    final page = active == null
        ? 1
        : (lastReadPageByDocumentId[active.id] ?? 1);
    viewport = PdfViewportData(currentPage: page, totalPages: 1, pageText: '');
  }

  PdfDocument applyTabColor(PdfDocument doc) {
    final value =
        tabColorsByDocumentId[doc.id] ?? tabColorsByDocumentId[doc.path];
    if (value == null) {
      return doc.copyWith(clearTabColor: true);
    }
    return doc.copyWith(tabColorValue: value);
  }

  List<PdfDocument> applyTabColors(List<PdfDocument> docs) {
    return docs.map(applyTabColor).toList(growable: false);
  }

  /// Returns `false` if a shortcut with this name already exists — the
  /// caller (composition root) is responsible for surfacing that as a
  /// SnackBar, since this controller has no BuildContext.
  Future<bool> createWorkspaceShortcut({
    required String name,
    required List<String> tabIds,
    int? colorValue,
  }) async {
    final normalizedName = name.trim().toLowerCase();
    final duplicateByName = workspaceShortcuts.any(
      (s) => s.name.trim().toLowerCase() == normalizedName,
    );
    if (duplicateByName) {
      return false;
    }
    final shortcut = WorkspaceShortcut(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      tabPaths: tabIds,
      colorValue: colorValue,
    );
    workspaceShortcuts = [...workspaceShortcuts, shortcut];
    await saveWorkspaceShortcuts();
    notifyListeners();
    return true;
  }

  Future<void> openWorkspaceShortcut(WorkspaceShortcut shortcut) async {
    final allDocs = await fileLibraryService.getDocuments();
    final coloredDocs = applyTabColors(allDocs);
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

    final existingById = {for (final doc in openTabs) doc.id: doc};
    for (final doc in docs) {
      existingById[doc.id] = doc;
    }
    openTabs = existingById.values.toList(growable: false);
    activeTabId = docs.first.id;
    restoreViewportForActiveDocument();
    section = AppSection.workspace;
    shortcutLaunchNonce++;
    shortcutLaunchRequest = ShortcutLaunchRequest(
      name: shortcut.name,
      tabIds: docs.map((d) => d.id).toList(growable: false),
      nonce: shortcutLaunchNonce,
      colorValue: shortcut.colorValue,
    );
    refreshAnnotations();
    notifyListeners();
  }

  Future<void> deleteWorkspaceShortcutByName(String name) async {
    workspaceShortcuts = workspaceShortcuts
        .where((s) => s.name.trim().toLowerCase() != name.trim().toLowerCase())
        .toList(growable: false);
    if (shortcutLaunchRequest != null &&
        shortcutLaunchRequest!.name.trim().toLowerCase() ==
            name.trim().toLowerCase()) {
      shortcutLaunchRequest = null;
    }
    await saveWorkspaceShortcuts();
    notifyListeners();
  }

  void consumeShortcutLaunch(int nonce) {
    if (shortcutLaunchRequest == null ||
        shortcutLaunchRequest!.nonce != nonce) {
      return;
    }
    shortcutLaunchRequest = null;
    notifyListeners();
  }

  Future<bool> renameWorkspaceShortcutByName(
    String oldName,
    String newName,
  ) async {
    final oldNorm = oldName.trim().toLowerCase();
    final newNorm = newName.trim().toLowerCase();
    if (oldNorm == newNorm) {
      return true;
    }

    final index = workspaceShortcuts.indexWhere(
      (s) => s.name.trim().toLowerCase() == oldNorm,
    );
    if (index == -1) {
      return true;
    }

    final duplicate = workspaceShortcuts.any(
      (s) =>
          s.name.trim().toLowerCase() == newNorm &&
          s.name.trim().toLowerCase() != oldNorm,
    );
    if (duplicate) {
      return false;
    }

    final current = workspaceShortcuts[index];
    workspaceShortcuts[index] = WorkspaceShortcut(
      id: current.id,
      name: newName,
      tabPaths: current.tabPaths,
      colorValue: current.colorValue,
    );
    await saveWorkspaceShortcuts();
    notifyListeners();
    return true;
  }

  Future<void> syncWorkspaceShortcutByName({
    required String name,
    required List<String> tabIds,
    int? colorValue,
  }) async {
    final norm = name.trim().toLowerCase();
    final index = workspaceShortcuts.indexWhere(
      (s) => s.name.trim().toLowerCase() == norm,
    );
    if (index == -1) {
      return;
    }
    final current = workspaceShortcuts[index];
    workspaceShortcuts[index] = WorkspaceShortcut(
      id: current.id,
      name: current.name,
      tabPaths: tabIds,
      colorValue: colorValue,
    );
    await saveWorkspaceShortcuts();
    notifyListeners();
  }

  Future<void> reloadLibrary() async {
    loading = true;
    notifyListeners();
    final loadedFolders = await fileLibraryService.getFolders();
    final docs = await fileLibraryService.getDocuments(
      folderRelativePath: selectedFolderPath,
    );
    folders = loadedFolders;
    documents = applyTabColors(docs);
    loading = false;
    notifyListeners();
  }

  Future<void> selectFolder(String folderPath) async {
    selectedFolderPath = folderPath;
    await reloadLibrary();
  }

  Future<void> createFolder(String folderName, String parentPath) async {
    await fileLibraryService.createFolder(
      name: folderName,
      parentRelativePath: parentPath,
    );
    await reloadLibrary();
  }

  Future<void> importPdfs({String? targetFolderPath}) async {
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

    await fileLibraryService.importPdfs(
      sourceFilePaths: pickedPaths,
      targetFolderRelativePath: targetFolderPath ?? selectedFolderPath,
    );
    await reloadLibrary();
  }

  Future<void> deleteDocument(PdfDocument document) async {
    // Close the tab (and notify) *before* touching the file on disk. If
    // this document is the active tab, its PdfViewerPanel holds a native
    // pdfium file handle that only releases in State.dispose() when the
    // widget unmounts — deleting the file first raced that handle and
    // reliably failed with "used by another process" on Windows.
    final wasOpen = openTabs.any((tab) => tab.id == document.id);
    openTabs = openTabs.where((tab) => tab.id != document.id).toList();
    if (activeTabId == document.id) {
      activeTabId = openTabs.isEmpty ? null : openTabs.last.id;
    }
    if (wasOpen) {
      notifyListeners();
      // Give the widget tree a couple of frames to actually unmount the
      // closed panel and run its dispose() before we try to delete the
      // file it had open.
      await Future.delayed(const Duration(milliseconds: 50));
    }
    await fileLibraryService.deleteDocument(document.path);
    tabColorsByDocumentId.remove(document.id);
    tabColorsByDocumentId.remove(document.path);
    await saveTabColors();
    lastReadPageByDocumentId.remove(document.id);
    lastReadPageByDocumentId.remove(document.path);
    await saveLastReadPages();
    await _pruneWorkspaceShortcuts(
      isValidPath: (path) => path != document.path && path != document.id,
    );
    await reloadLibrary();
    refreshAnnotations();
    notifyListeners();
    await _broadcastAi();
    await _broadcastNotes();
  }

  Future<void> deleteFolder(String folderPath) async {
    final normalized = folderPath.replaceAll('/', '\\').toLowerCase();
    final absoluteFolderPath =
        '\\${libraryRoot.replaceAll('/', '\\').toLowerCase()}\\$normalized\\';
    final tabColorKeysToDelete = tabColorsByDocumentId.keys
        .where(
          (path) => '\\${path.replaceAll('/', '\\').toLowerCase()}\\'
              .startsWith(absoluteFolderPath),
        )
        .toList(growable: false);
    for (final key in tabColorKeysToDelete) {
      tabColorsByDocumentId.remove(key);
    }
    if (tabColorKeysToDelete.isNotEmpty) {
      await saveTabColors();
    }
    final pageKeysToDelete = lastReadPageByDocumentId.keys
        .where(
          (path) => '\\${path.replaceAll('/', '\\').toLowerCase()}\\'
              .startsWith(absoluteFolderPath),
        )
        .toList(growable: false);
    for (final key in pageKeysToDelete) {
      lastReadPageByDocumentId.remove(key);
    }
    if (pageKeysToDelete.isNotEmpty) {
      await saveLastReadPages();
    }
    // Remove affected open tabs first so viewer file handles are released.
    openTabs = openTabs
        .where(
          (tab) => !tab.folderPath
              .replaceAll('/', '\\')
              .toLowerCase()
              .startsWith(normalized),
        )
        .toList(growable: true);
    if (openTabs.every((tab) => tab.id != activeTabId)) {
      activeTabId = openTabs.isEmpty ? null : openTabs.last.id;
    }
    if (selectedFolderPath.replaceAll('/', '\\').toLowerCase() == normalized) {
      selectedFolderPath = '';
    }
    folders = folders
        .where(
          (f) =>
              f.path.isEmpty ||
              !f.path
                  .replaceAll('/', '\\')
                  .toLowerCase()
                  .startsWith(normalized),
        )
        .toList(growable: false);
    await _pruneWorkspaceShortcuts(
      isValidPath: (path) => !'\\${path.replaceAll('/', '\\').toLowerCase()}\\'
          .startsWith(absoluteFolderPath),
    );
    notifyListeners();

    // Give flutter/widgets one frame to detach viewers from soon-to-delete files.
    await Future<void>.delayed(const Duration(milliseconds: 120));

    await fileLibraryService.deleteFolder(folderPath);
    await reloadLibrary();
    refreshAnnotations();
    notifyListeners();
    await _broadcastAi();
    await _broadcastNotes();
  }

  Future<bool> createWorkspaceShortcutFromDocuments(
    String name,
    List<PdfDocument> documentsToAdd,
  ) async {
    final ok = await createWorkspaceShortcut(
      name: name,
      tabIds: documentsToAdd.map((d) => d.path).toList(growable: false),
    );
    if (!ok) {
      return false;
    }

    final existingById = {for (final doc in openTabs) doc.id: doc};
    final coloredDocs = applyTabColors(documentsToAdd);
    for (final doc in coloredDocs) {
      existingById[doc.id] = doc;
    }
    openTabs = existingById.values.toList(growable: false);
    activeTabId = coloredDocs.first.id;
    restoreViewportForActiveDocument();
    section = AppSection.workspace;
    shortcutLaunchNonce++;
    shortcutLaunchRequest = ShortcutLaunchRequest(
      name: name,
      tabIds: coloredDocs.map((d) => d.id).toList(growable: false),
      nonce: shortcutLaunchNonce,
      colorValue: null,
    );
    refreshAnnotations();
    notifyListeners();
    return true;
  }

  void openDocument(PdfDocument document) {
    final colored = applyTabColor(document);
    if (!openTabs.any((tab) => tab.id == colored.id)) {
      openTabs = [...openTabs, colored];
    }
    activeTabId = colored.id;
    restoreViewportForActiveDocument();
    section = AppSection.workspace;
    refreshAnnotations();
    _broadcastAi();
    _broadcastNotes();
    notifyListeners();
  }

  void openMergedNote(MergedNote note) {
    final pseudoDoc = PdfDocument(
      id: 'note-${note.id}',
      path: 'note://${note.id}',
      title: 'Notes: ${note.pdfTitle}',
      lastOpened: DateTime.now(),
    );
    if (!openTabs.any((tab) => tab.id == pseudoDoc.id)) {
      openTabs = [...openTabs, pseudoDoc];
    }
    activeTabId = pseudoDoc.id;
    restoreViewportForActiveDocument();
    section = AppSection.workspace;
    notifyListeners();
  }

  Future<void> mergeNotesForTab(String documentId) async {
    PdfDocument? doc;
    for (final d in documents) {
      if (d.id == documentId) doc = d;
    }
    if (doc == null) {
      for (final d in openTabs) {
        if (d.id == documentId) doc = d;
      }
    }
    if (doc == null) return;

    final notes = await richNotesStore.getNotesForPdf(documentId);
    final buffer = StringBuffer();
    buffer.writeln('# Notes for ${doc.title}\n');

    if (notes.isEmpty) {
      buffer.writeln('No notes have been added to this document yet.');
    } else {
      buffer.writeln('## Agenda');
      for (final note in notes) {
        // Must match the slug _HeadingBuilder computes for the matching
        // "## Page N" heading below, or the link silently fails to scroll.
        buffer.writeln(
          '- [Page ${note.pageNumber}](#${toSlug('Page ${note.pageNumber}')})',
        );
      }
      buffer.writeln('\n---');

      for (final note in notes) {
        buffer.writeln('\n## Page ${note.pageNumber}');
        buffer.writeln(deltaJsonToPlainText(note.deltaJson));
      }
    }

    final existing = mergedNotesStore.getNoteByPdfId(documentId);
    final merged = MergedNote(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      pdfId: documentId,
      pdfTitle: doc.title,
      markdownContent: buffer.toString(),
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await mergedNotesStore.saveNote(merged);
    openMergedNote(merged);
  }

  Future<void> mergeNotesForGroup(String groupName, List<String> tabIds) async {
    final buffer = StringBuffer();
    buffer.writeln('# Master Notes for $groupName\n');

    // First pass to build master agenda
    buffer.writeln('## Master Agenda');
    for (final tabId in tabIds) {
      PdfDocument? doc;
      for (final d in documents) {
        if (d.id == tabId) doc = d;
      }
      if (doc == null) {
        for (final d in openTabs) {
          if (d.id == tabId) doc = d;
        }
      }
      if (doc == null) continue;

      final notes = await richNotesStore.getNotesForPdf(doc.id);
      if (notes.isEmpty) continue;

      // Must match the h2-scoped slug _HeadingBuilder computes for the
      // "## docTitle" / "### Page N" headings below: an h3's key is
      // "<h2-slug>--<h3-slug>", not its own text alone, since multiple
      // documents in this workspace can each have a "Page 1" heading and
      // those need distinct anchors. See _HeadingBuilder's class doc.
      final docSlug = toSlug(doc.title);
      buffer.writeln('- [${doc.title}](#$docSlug)');

      for (final note in notes) {
        final pageSlug = toSlug('Page ${note.pageNumber}');
        buffer.writeln('  - [Page ${note.pageNumber}](#$docSlug--$pageSlug)');
      }
    }
    buffer.writeln('\n---\n');

    // Second pass to write content
    bool hasAnyNotes = false;
    for (final tabId in tabIds) {
      PdfDocument? doc;
      for (final d in documents) {
        if (d.id == tabId) doc = d;
      }
      if (doc == null) {
        for (final d in openTabs) {
          if (d.id == tabId) doc = d;
        }
      }
      if (doc == null) continue;

      final notes = await richNotesStore.getNotesForPdf(doc.id);
      if (notes.isEmpty) continue;

      hasAnyNotes = true;
      buffer.writeln('## ${doc.title}');

      for (final note in notes) {
        buffer.writeln('\n### Page ${note.pageNumber}');
        buffer.writeln(deltaJsonToPlainText(note.deltaJson));
      }
      buffer.writeln('\n---\n');
    }

    if (!hasAnyNotes) {
      buffer.writeln(
        'No notes have been added to any documents in this workspace yet.',
      );
    }

    // Using the group name mapped into an ID string to ensure replacement
    final pseudoNoteId = 'group-${groupName.replaceAll(RegExp(r'\s+'), '_')}';
    final existing = mergedNotesStore.getNoteById(pseudoNoteId);

    final merged = MergedNote(
      id: pseudoNoteId,
      pdfId: 'group', // Re-use pdfId to store a marker for group
      pdfTitle: 'Master: $groupName',
      markdownContent: buffer.toString(),
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await mergedNotesStore.saveNote(merged);
    openMergedNote(merged);
  }

  Future<void> saveMergedNote(String text) async {
    final active = activeDocument;
    if (active == null || !active.id.startsWith('note-')) return;

    final noteId = active.id.substring(5);
    final existing = mergedNotesStore.getNoteById(noteId);
    if (existing != null) {
      final updated = existing.copyWith(
        markdownContent: text,
        updatedAt: DateTime.now(),
      );
      await mergedNotesStore.saveNote(updated);

      // Two-way sync: Update page notes in RichNotesStore
      await syncMarkdownToRichNotes(text);

      notifyListeners();
    }
  }

  Future<void> syncMarkdownToRichNotes(String markdown) async {
    final lines = markdown.split('\n');
    String? currentPdfId;
    int? currentPage;
    final StringBuffer currentText = StringBuffer();

    Future<void> saveCurrentBuffer() async {
      final docId = currentPdfId;
      final page = currentPage;
      if (docId != null && page != null && currentText.isNotEmpty) {
        final content = currentText.toString().trim();
        if (content.isNotEmpty) {
          await richNotesStore.upsertNote(
            pdfId: docId,
            pageNumber: page,
            deltaJson: toPlainTextDeltaJson(content),
          );
        }
      }
      currentText.clear();
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('## ') &&
          !line.startsWith('### ') &&
          !line.startsWith('## Agenda') &&
          !line.startsWith('## Master')) {
        // Discovered a document title
        await saveCurrentBuffer();
        currentPage = null;

        final title = line.substring(3).trim();
        PdfDocument? targetDoc;
        for (final doc in documents) {
          if (doc.title == title) targetDoc = doc;
        }
        if (targetDoc == null) {
          for (final doc in openTabs) {
            if (doc.title == title) targetDoc = doc;
          }
        }
        currentPdfId = targetDoc?.id;
      } else if (line.startsWith('### Page ') && currentPdfId != null) {
        // Discovered a page header
        await saveCurrentBuffer();
        final numStr = line.substring(9).trim();
        final parsed = int.tryParse(numStr);
        if (parsed != null) {
          currentPage = parsed;
        } else {
          currentPage = null;
        }
      } else if (currentPage != null && currentPdfId != null) {
        // Accumulate page content, ignoring divider dashes
        if (line.trim() != '---') {
          currentText.writeln(line);
        }
      }
    }

    // Save trailing buffer
    await saveCurrentBuffer();
    refreshAnnotations();
    await _broadcastNotes();
  }

  Future<void> renameMergedNote(String noteId, String newTitle) async {
    final existing = mergedNotesStore.getNoteById(noteId);
    if (existing != null) {
      final updated = existing.copyWith(
        pdfTitle: newTitle,
        updatedAt: DateTime.now(),
      );
      await mergedNotesStore.saveNote(updated);

      final tabId = 'note-$noteId';
      openTabs = openTabs
          .map((t) {
            if (t.id == tabId) {
              return t.copyWith(title: 'Notes: $newTitle');
            }
            return t;
          })
          .toList(growable: false);
      notifyListeners();
    }
  }

  void closeTab(String documentId) {
    openTabs = openTabs.where((tab) => tab.id != documentId).toList();
    if (activeTabId == documentId) {
      activeTabId = openTabs.isEmpty ? null : openTabs.last.id;
      restoreViewportForActiveDocument();
    }
    refreshAnnotations();
    _broadcastAi();
    _broadcastNotes();
    notifyListeners();
  }

  void switchTab(String documentId) {
    activeTabId = documentId;
    restoreViewportForActiveDocument();
    refreshAnnotations();
    _broadcastAi();
    _broadcastNotes();
    notifyListeners();
  }

  Future<void> setTabColor(String documentId, int? colorValue) async {
    if (colorValue == null) {
      tabColorsByDocumentId.remove(documentId);
    } else {
      tabColorsByDocumentId[documentId] = colorValue;
    }
    await saveTabColors();

    documents = documents
        .map(
          (d) => d.id == documentId
              ? (colorValue == null
                    ? d.copyWith(clearTabColor: true)
                    : d.copyWith(tabColorValue: colorValue))
              : d,
        )
        .toList(growable: false);
    openTabs = openTabs
        .map(
          (d) => d.id == documentId
              ? (colorValue == null
                    ? d.copyWith(clearTabColor: true)
                    : d.copyWith(tabColorValue: colorValue))
              : d,
        )
        .toList(growable: false);
    notifyListeners();
  }

  void onViewportChanged(PdfViewportData viewportData) {
    viewport = viewportData;
    final active = activeDocument;
    if (active != null) {
      final previous = lastReadPageByDocumentId[active.id];
      if (previous != viewportData.currentPage) {
        lastReadPageByDocumentId[active.id] = viewportData.currentPage;
        saveLastReadPages();
      }
    }
    refreshAnnotations();
    _broadcastAi();
    _broadcastNotes();
    notifyListeners();
  }

  void saveAnnotation(String text) async {
    final active = activeDocument;
    if (active == null || text.trim().isEmpty) {
      return;
    }
    final trimmed = text.trim();

    store.upsertAnnotation(
      Annotation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        pdfId: active.id,
        pageNumber: viewport.currentPage,
        content: trimmed,
        createdAt: DateTime.now(),
      ),
    );
    await richNotesStore.upsertNote(
      pdfId: active.id,
      pageNumber: viewport.currentPage,
      deltaJson: toPlainTextDeltaJson(trimmed),
    );

    refreshAnnotations();
    _broadcastNotes();
    notifyListeners();
  }

  String toPlainTextDeltaJson(String text) {
    final normalized = text.endsWith('\n') ? text : '$text\n';
    return jsonEncode([
      {'insert': normalized},
    ]);
  }

  String deltaJsonToPlainText(String deltaJson) {
    try {
      final decoded = jsonDecode(deltaJson);
      if (decoded is! List) {
        return deltaJson;
      }
      final buffer = StringBuffer();
      for (final op in decoded) {
        if (op is Map && op['insert'] is String) {
          buffer.write(op['insert'] as String);
        }
      }
      return buffer.toString().trim();
    } catch (_) {
      return deltaJson;
    }
  }

  void refreshAnnotations() {
    final active = activeDocument;
    if (active == null) {
      pageAnnotations = const [];
      return;
    }
    final rich = richNotesStore.peekNote(
      pdfId: active.id,
      pageNumber: viewport.currentPage,
    );
    if (rich != null && rich.deltaJson.trim().isNotEmpty) {
      pageAnnotations = <Annotation>[
        Annotation(
          id: rich.id,
          pdfId: active.id,
          pageNumber: viewport.currentPage,
          content: deltaJsonToPlainText(rich.deltaJson),
          createdAt: rich.updatedAt,
        ),
      ];
      store.upsertAnnotation(pageAnnotations.first);
      return;
    }
    pageAnnotations = store.getAnnotations(
      pdfId: active.id,
      page: viewport.currentPage,
    );
  }

  List<Map<String, dynamic>> serializedAnnotations() {
    return pageAnnotations
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

  /// [downloadsPath] comes from `AiSettingsController.downloaderDownloadsPath`
  /// — the PESU downloader's bridge/process logic lives there, but importing
  /// the resulting PDFs into the library is a workspace/library concern.
  Future<void> importDownloaderPdfs(String downloadsPath) async {
    final downloadsDir = Directory(downloadsPath);
    if (!downloadsDir.existsSync()) {
      throw Exception('No downloads folder found yet at $downloadsPath');
    }
    final pdfPaths = downloadsDir
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.toLowerCase().endsWith('.pdf'))
        .toList(growable: false);
    if (pdfPaths.isEmpty) {
      throw Exception(
        'No PDFs found in downloader output.\nExpected under $downloadsPath',
      );
    }

    await fileLibraryService.importPdfs(
      sourceFilePaths: pdfPaths,
      targetFolderRelativePath: selectedFolderPath,
    );
    await reloadLibrary();
    section = AppSection.home;
    notifyListeners();
  }
}
