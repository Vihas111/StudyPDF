import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:studypdf/core/ai/ai_provider_registry.dart';
import 'package:studypdf/features/ai_assistant/presentation/ai_assistant_panel.dart';
import 'package:studypdf/features/notes/presentation/page_notes_panel.dart';
import 'package:studypdf/models/annotation.dart';

class ExternalPanelApp extends StatelessWidget {
  const ExternalPanelApp({super.key, required this.payloadJson});

  final String payloadJson;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> payload = {};
    try {
      payload = jsonDecode(payloadJson) as Map<String, dynamic>;
    } catch (_) {
      payload = {'panel': 'unknown'};
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StudyPDF Panel',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF255F85)),
      ),
      home: _ExternalPanelScreen(payload: payload),
    );
  }
}

class _ExternalPanelScreen extends StatefulWidget {
  const _ExternalPanelScreen({required this.payload});

  final Map<String, dynamic> payload;

  @override
  State<_ExternalPanelScreen> createState() => _ExternalPanelScreenState();
}

class _ExternalPanelScreenState extends State<_ExternalPanelScreen> {
  final AIProviderRegistry _providerRegistry = AIProviderRegistry();
  late List<Annotation> _notes;
  String _panel = 'unknown';
  String _documentId = '';
  String _documentTitle = 'Document';
  int _pageNumber = 1;
  String _pageText = '';

  @override
  void initState() {
    super.initState();
    _hydrateFromPayload(widget.payload);

    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'mainStateUpdated') {
        final data = (call.arguments as Map).cast<String, dynamic>();
        _hydrateFromPayload(data);
        if (mounted) {
          setState(() {});
        }
        return {'ok': true};
      }
      return null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      DesktopMultiWindow.invokeMethod(0, 'externalWindowReady', {
        'panel': _panel,
      });
    });
  }

  void _hydrateFromPayload(Map<String, dynamic> payload) {
    _panel = payload['panel'] as String? ?? _panel;
    _documentId = payload['documentId'] as String? ?? _documentId;
    _documentTitle = payload['documentTitle'] as String? ?? _documentTitle;
    _pageNumber = payload['pageNumber'] as int? ?? _pageNumber;
    _pageText = payload['pageText'] as String? ?? _pageText;
    final rawNotes = payload['annotations'] as List<dynamic>? ?? const [];
    _notes = rawNotes
        .map((item) {
          final map = item as Map<String, dynamic>;
          return Annotation(
            id: map['id'] as String? ?? '',
            pdfId: map['pdfId'] as String? ?? '',
            pageNumber: map['pageNumber'] as int? ?? 1,
            content: map['content'] as String? ?? '',
            createdAt:
                DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                DateTime.now(),
          );
        })
        .toList(growable: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _panel == 'ai'
              ? 'AI Assistant - $_documentTitle'
              : 'Notes - $_documentTitle (Page $_pageNumber)',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: switch (_panel) {
          'ai' => AIAssistantPanel(
            providers: _providerRegistry.all,
            onRunPrompt: ({required providerId, required prompt}) async {
              final response = await _providerRegistry
                  .resolve(providerId)
                  .sendPrompt(prompt: prompt, context: _pageText);
              await DesktopMultiWindow.invokeMethod(
                0,
                'externalAiOutputUpdated',
                {'assistantOutput': response},
              );
              return response;
            },
          ),
          'notes' => PageNotesPanel(
            pageNumber: _pageNumber,
            annotations: _notes,
            onSave: (text) async {
              if (text.trim().isEmpty) {
                return;
              }
              final annotation = Annotation(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                pdfId: _documentId,
                pageNumber: _pageNumber,
                content: text.trim(),
                createdAt: DateTime.now(),
              );
              setState(() {
                _notes.insert(0, annotation);
              });
              await DesktopMultiWindow.invokeMethod(0, 'externalNoteSaved', {
                'id': annotation.id,
                'pdfId': annotation.pdfId,
                'pageNumber': annotation.pageNumber,
                'content': annotation.content,
                'createdAt': annotation.createdAt.toIso8601String(),
              });
            },
          ),
          _ => const Center(child: Text('Unsupported external panel payload')),
        },
      ),
    );
  }
}
