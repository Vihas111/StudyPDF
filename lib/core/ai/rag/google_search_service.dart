import 'dart:convert';
import 'dart:io';

class WebContextResult {
  const WebContextResult({required this.context, required this.sources});

  final String context;
  final List<String> sources;
}

class GoogleSearchService {
  Future<WebContextResult> search({
    required String query,
    required String apiKey,
    required String searchEngineId,
    int maxResults = 3,
  }) async {
    final key = apiKey.trim();
    final cx = searchEngineId.trim();
    final q = query.trim();
    if (key.isEmpty || cx.isEmpty || q.isEmpty) {
      return const WebContextResult(context: '', sources: <String>[]);
    }

    final uri = Uri.https('www.googleapis.com', '/customsearch/v1', {
      'key': key,
      'cx': cx,
      'q': q,
      'num': maxResults.clamp(1, 10).toString(),
      'safe': 'active',
    });

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const WebContextResult(context: '', sources: <String>[]);
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return const WebContextResult(context: '', sources: <String>[]);
      }
      final items = decoded['items'];
      if (items is! List) {
        return const WebContextResult(context: '', sources: <String>[]);
      }

      final snippets = <String>[];
      final sources = <String>[];
      var i = 1;
      for (final item in items) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final title = item['title']?.toString().trim() ?? '';
        final snippet = item['snippet']?.toString().trim() ?? '';
        final link = item['link']?.toString().trim() ?? '';
        if (title.isEmpty && snippet.isEmpty) {
          continue;
        }
        snippets.add('[web$i] ${title.isEmpty ? 'Untitled' : title}\n$snippet');
        if (link.isNotEmpty) {
          sources.add('[web$i] $link');
        }
        i++;
      }

      return WebContextResult(context: snippets.join('\n\n'), sources: sources);
    } catch (_) {
      return const WebContextResult(context: '', sources: <String>[]);
    } finally {
      client.close(force: true);
    }
  }
}
