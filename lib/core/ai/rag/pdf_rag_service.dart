import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

class RagContextResult {
  const RagContextResult({required this.context, required this.pages});

  final String context;
  final List<int> pages;
}

class PdfRagService {
  final Map<String, _CachedDocument> _cache = <String, _CachedDocument>{};

  Future<RagContextResult> buildContext({
    required String pdfPath,
    required String query,
    int topK = 4,
  }) async {
    final file = File(pdfPath);
    if (!file.existsSync()) {
      return const RagContextResult(context: '', pages: <int>[]);
    }

    final cached = await _getOrBuildChunks(file);
    if (cached.isEmpty) {
      return const RagContextResult(context: '', pages: <int>[]);
    }

    final queryTokens = _tokens(query);
    final scored =
        cached
            .map(
              (chunk) =>
                  (chunk: chunk, score: _score(query, queryTokens, chunk)),
            )
            .where((it) => it.score > 0)
            .toList(growable: false)
          ..sort((a, b) => b.score.compareTo(a.score));

    final selected =
        (scored.isEmpty
                ? cached.take(topK).map((c) => (chunk: c, score: 0.0))
                : scored.take(topK))
            .map((e) => e.chunk)
            .toList(growable: false);

    final pages = selected.map((c) => c.page).toSet().toList(growable: false)
      ..sort();
    final context = selected
        .map((c) => '[Page ${c.page}]\n${c.text}')
        .join('\n\n---\n\n');

    return RagContextResult(context: context, pages: pages);
  }

  Future<List<_RagChunk>> _getOrBuildChunks(File file) async {
    final stat = await file.stat();
    final cacheKey = file.path;
    final cached = _cache[cacheKey];
    if (cached != null &&
        cached.modifiedMs == stat.modified.millisecondsSinceEpoch &&
        cached.size == stat.size) {
      return cached.chunks;
    }

    final bytes = await file.readAsBytes();
    final doc = sfpdf.PdfDocument(inputBytes: bytes);
    try {
      final extractor = sfpdf.PdfTextExtractor(doc);
      final chunks = <_RagChunk>[];
      for (var pageIndex = 0; pageIndex < doc.pages.count; pageIndex++) {
        final raw = extractor.extractText(
          startPageIndex: pageIndex,
          endPageIndex: pageIndex,
        );
        final normalized = raw.replaceAll('\r', '\n').trim();
        if (normalized.isEmpty) {
          continue;
        }

        final paragraphs = normalized
            .split(RegExp(r'\n{2,}'))
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList(growable: false);
        for (final part in paragraphs) {
          if (part.length <= 900) {
            chunks.add(
              _RagChunk(page: pageIndex + 1, text: part, tokens: _tokens(part)),
            );
          } else {
            var start = 0;
            while (start < part.length) {
              final end = (start + 900).clamp(0, part.length);
              final slice = part.substring(start, end).trim();
              if (slice.isNotEmpty) {
                chunks.add(
                  _RagChunk(
                    page: pageIndex + 1,
                    text: slice,
                    tokens: _tokens(slice),
                  ),
                );
              }
              if (end == part.length) {
                break;
              }
              start = (end - 120).clamp(0, part.length);
            }
          }
        }
      }

      _cache[cacheKey] = _CachedDocument(
        modifiedMs: stat.modified.millisecondsSinceEpoch,
        size: stat.size,
        chunks: chunks,
      );
      return chunks;
    } finally {
      doc.dispose();
    }
  }

  Set<String> _tokens(String input) {
    final parts = input
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((s) => s.length > 2)
        .where((s) => !_stopWords.contains(s))
        .toSet();
    return parts;
  }

  double _score(String query, Set<String> queryTokens, _RagChunk chunk) {
    if (queryTokens.isEmpty || chunk.tokens.isEmpty) {
      return 0;
    }
    var overlap = 0;
    for (final t in queryTokens) {
      if (chunk.tokens.contains(t)) {
        overlap++;
      }
    }
    final q = query.toLowerCase();
    final phraseBoost = chunk.text.toLowerCase().contains(q) ? 2.0 : 0.0;
    return overlap + phraseBoost;
  }
}

class _CachedDocument {
  const _CachedDocument({
    required this.modifiedMs,
    required this.size,
    required this.chunks,
  });

  final int modifiedMs;
  final int size;
  final List<_RagChunk> chunks;
}

class _RagChunk {
  const _RagChunk({
    required this.page,
    required this.text,
    required this.tokens,
  });

  final int page;
  final String text;
  final Set<String> tokens;
}

const Set<String> _stopWords = <String>{
  'the',
  'and',
  'for',
  'with',
  'that',
  'this',
  'from',
  'are',
  'was',
  'were',
  'have',
  'has',
  'had',
  'not',
  'you',
  'your',
  'but',
  'can',
  'will',
  'into',
  'its',
  'also',
  'use',
  'used',
  'using',
  'how',
  'what',
  'when',
  'where',
  'why',
  'who',
  'which',
  'all',
  'any',
  'each',
  'than',
  'then',
  'their',
  'there',
  'about',
  'page',
  'pdf',
};
