import 'dart:convert';
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:studypdf/core/state/ai_settings_controller.dart';
import 'package:studypdf/core/state/workspace_controller.dart';
import 'package:studypdf/models/annotation.dart';

/// Orchestrates the `desktop_multi_window` pop-out AI/Notes windows —
/// extracted from `_StudyShellPageState` in `lib/app.dart` (Phase 0
/// refactor).
///
/// This controller needs read access to both [workspace] and [ai] state to
/// build the JSON payloads the pop-out windows expect, so it takes both as
/// constructor dependencies (composition, not inheritance) rather than
/// duplicating their fields.
///
/// IMPORTANT: every field read here was traced from the original
/// `_openExternalAiWindow`/`_openExternalNotesWindow`/`_pushAiStateToWindow`/
/// `_pushNotesStateToWindow` methods so the pop-out windows keep receiving
/// exactly the same payload shape as before the split.
class WindowController extends ChangeNotifier {
  WindowController({required this.workspace, required this.ai}) {
    ai.onAiStateShouldBroadcast = broadcastAiState;
    workspace.onAiStateShouldBroadcast = broadcastAiState;
    workspace.onNotesStateShouldBroadcast = broadcastNotesState;
  }

  final WorkspaceController workspace;
  final AiSettingsController ai;

  final Set<int> externalAiWindowIds = <int>{};
  final Set<int> externalNotesWindowIds = <int>{};

  void setupInterWindowSync() {
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'externalWindowReady') {
        final data = (call.arguments as Map).cast<String, dynamic>();
        final panel = data['panel'] as String? ?? '';
        if (panel == 'ai') {
          externalAiWindowIds.add(fromWindowId);
          await pushAiStateToWindow(fromWindowId);
        } else if (panel == 'notes') {
          externalNotesWindowIds.add(fromWindowId);
          await pushNotesStateToWindow(fromWindowId);
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
        workspace.store.upsertAnnotation(annotation);
        await workspace.richNotesStore.upsertNote(
          pdfId: annotation.pdfId,
          pageNumber: annotation.pageNumber,
          deltaJson: workspace.toPlainTextDeltaJson(annotation.content),
        );
        if (workspace.activeDocument?.id == annotation.pdfId &&
            workspace.viewport.currentPage == annotation.pageNumber) {
          workspace.refreshAnnotations();
          workspace.notifyChanged();
        }
        await broadcastNotesState();
        return {'ok': true};
      }

      if (call.method == 'externalAiOutputUpdated') {
        final data = (call.arguments as Map).cast<String, dynamic>();
        final text = data['assistantOutput'] as String? ?? '';
        final providerId = data['providerId'] as String? ?? '';
        if (providerId.isNotEmpty && providerId != ai.activeAiProviderId) {
          ai.activeAiProviderId = providerId;
        }
        if (text.isNotEmpty) {
          ai.assistantOutput = text;
          ai.notifyChanged();
          await broadcastAiState();
        }
        return {'ok': true};
      }

      if (call.method == 'externalAiProviderChanged') {
        final data = (call.arguments as Map).cast<String, dynamic>();
        final providerId = data['providerId'] as String? ?? '';
        if (providerId.isNotEmpty) {
          ai.handleAiProviderChanged(providerId);
          return {'ok': true};
        }
        return {'ok': false};
      }

      return null;
    });
  }

  Future<void> openExternalAiWindow() async {
    final active = workspace.activeDocument;
    if (active == null) {
      return;
    }
    final payload = jsonEncode({
      'panel': 'ai',
      'documentId': active.id,
      'documentTitle': active.title,
      'pageNumber': workspace.viewport.currentPage,
      'pageText': workspace.viewport.pageText,
      'assistantOutput': ai.assistantOutput,
      'themeMode': workspace.themeModeToString(workspace.themeMode),
      'activeAiProviderId': ai.activeAiProviderId,
      'apiKeys': {
        'openai': ai.openAiApiKey,
        'groq': ai.groqApiKey,
        'gemini': ai.geminiApiKey,
      },
    });

    final window = await DesktopMultiWindow.createWindow(payload);
    externalAiWindowIds.add(window.windowId);
    window
      ..setFrame(const Offset(120, 120) & const Size(520, 760))
      ..setTitle('StudyPDF - AI Assistant')
      ..show();
  }

  Future<void> openExternalNotesWindow() async {
    final active = workspace.activeDocument;
    if (active == null) {
      return;
    }
    final payload = jsonEncode({
      'panel': 'notes',
      'documentId': active.id,
      'documentTitle': active.title,
      'pageNumber': workspace.viewport.currentPage,
      'annotations': workspace.pageAnnotations
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
    externalNotesWindowIds.add(window.windowId);
    window
      ..setFrame(const Offset(180, 180) & const Size(700, 760))
      ..setTitle('StudyPDF - Notes')
      ..show();
  }

  Future<void> broadcastAiState() async {
    for (final id in externalAiWindowIds.toList(growable: false)) {
      await pushAiStateToWindow(id);
    }
  }

  Future<void> broadcastNotesState() async {
    for (final id in externalNotesWindowIds.toList(growable: false)) {
      await pushNotesStateToWindow(id);
    }
  }

  Future<void> pushAiStateToWindow(int id) async {
    try {
      await DesktopMultiWindow.invokeMethod(id, 'mainStateUpdated', {
        'panel': 'ai',
        'documentId': workspace.activeDocument?.id,
        'documentTitle': workspace.activeDocument?.title,
        'pageNumber': workspace.viewport.currentPage,
        'pageText': workspace.viewport.pageText,
        'assistantOutput': ai.assistantOutput,
        'themeMode': workspace.themeModeToString(workspace.themeMode),
        'activeAiProviderId': ai.activeAiProviderId,
        'apiKeys': {
          'openai': ai.openAiApiKey,
          'groq': ai.groqApiKey,
          'gemini': ai.geminiApiKey,
        },
      });
    } catch (_) {
      externalAiWindowIds.remove(id);
    }
  }

  Future<void> pushNotesStateToWindow(int id) async {
    try {
      await DesktopMultiWindow.invokeMethod(id, 'mainStateUpdated', {
        'panel': 'notes',
        'documentId': workspace.activeDocument?.id,
        'documentTitle': workspace.activeDocument?.title,
        'pageNumber': workspace.viewport.currentPage,
        'annotations': workspace.serializedAnnotations(),
      });
    } catch (_) {
      externalNotesWindowIds.remove(id);
    }
  }
}
