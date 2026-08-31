import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Result of transcribing a photo of handwritten (or printed) notes.
class HandwritingTranscription {
  const HandwritingTranscription({
    required this.text,
    required this.hasNonTextContent,
  });

  /// The transcribed text, as markdown. Empty if nothing legible was found.
  final String text;

  /// True if the model judged the page to contain a diagram/drawing/sketch
  /// that isn't transcribable text — the caller should offer to keep the
  /// original photo attached alongside the transcribed text in that case,
  /// since a general vision-chat model can't reliably crop out just the
  /// diagram region (no bounding-box/segmentation output available on the
  /// free tier) — keeping the whole photo is the practical fallback.
  final bool hasNonTextContent;
}

/// Transcribes photos of handwritten notes via a vision-capable OpenRouter
/// model. Uses the OpenRouter chat completions endpoint directly (same
/// OpenAI-compatible shape as [OpenRouterProvider]) rather than going
/// through the [AIProvider] interface, since this needs multimodal
/// (image + text) input that the plain text Q&A interface doesn't model.
class OcrService {
  /// `minimax/minimax-m3:free` is used unconditionally for OCR rather than
  /// whatever chat model the user has picked in Settings, because OCR needs
  /// a vision-capable model specifically — the user's chat-model choice
  /// (e.g. a text-only free model) would otherwise silently fail here.
  /// Verified against OpenRouter's live catalog to support image input.
  static const String _visionModel = 'minimax/minimax-m3:free';

  static const String _prompt = '''
You are transcribing a photo of a student's handwritten (or printed) note page.

Respond with ONLY a JSON object, no other text, in this exact shape:
{"text": "<the transcribed text, formatted as markdown - use ## for headings and - for bullet lists where appropriate>", "hasNonTextContent": <true or false>}

Rules:
- Transcribe all legible handwritten/printed text as accurately as possible.
- Preserve the reading order and structure (headings, bullet points, numbered lists) as markdown.
- Set "hasNonTextContent" to true if the page contains a diagram, sketch, chart, or drawing that is not representable as text; otherwise false.
- Do not describe the diagram in the text field - just note its rough location with a short bracketed note like "[diagram]" if useful. The image itself will be attached separately.
- If nothing is legible, return {"text": "", "hasNonTextContent": false}.
''';

  Future<HandwritingTranscription> transcribeHandwriting({
    required Uint8List imageBytes,
    required String apiKey,
    required String mimeType,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw Exception(
        'OpenRouter API key is missing. Add it in Settings > AI Settings to use handwriting import.',
      );
    }

    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      request.headers.set('HTTP-Referer', 'https://github.com/studypdf');
      request.headers.set('X-Title', 'StudyPDF');

      final base64Image = base64Encode(imageBytes);
      final payload = jsonEncode({
        'model': _visionModel,
        'temperature': 0.1,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': _prompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:$mimeType;base64,$base64Image'},
              },
            ],
          },
        ],
      });

      request.add(utf8.encode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final decoded = _tryDecodeJson(body);
        final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
        final message = (error is Map<String, dynamic>)
            ? error['message']?.toString() ?? 'Unknown error'
            : 'Request failed with status ${response.statusCode}';
        throw Exception('Handwriting import failed: $message');
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw Exception('Handwriting import returned no result.');
      }
      final message = (choices.first as Map<String, dynamic>)['message'];
      final content = (message is Map<String, dynamic>)
          ? message['content']?.toString().trim() ?? ''
          : '';
      if (content.isEmpty) {
        throw Exception('Handwriting import returned an empty response.');
      }

      return _parseTranscription(content);
    } on SocketException catch (e) {
      throw Exception('Network error while transcribing: ${e.message}');
    } finally {
      client.close(force: true);
    }
  }

  dynamic _tryDecodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  HandwritingTranscription _parseTranscription(String content) {
    // Models sometimes wrap JSON in a ```json fence despite instructions;
    // strip that before parsing.
    var cleaned = content.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '')
          .replaceFirst(RegExp(r'```\s*$'), '')
          .trim();
    }

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return HandwritingTranscription(
          text: decoded['text']?.toString() ?? '',
          hasNonTextContent: decoded['hasNonTextContent'] == true,
        );
      }
    } catch (_) {
      // Fall through: treat the raw response as plain transcribed text
      // rather than failing outright, in case the model didn't follow the
      // JSON format.
    }
    return HandwritingTranscription(text: cleaned, hasNonTextContent: false);
  }
}
