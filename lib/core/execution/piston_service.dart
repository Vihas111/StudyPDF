import 'dart:convert';
import 'dart:io';

import 'package:studypdf/core/execution/code_execution_result.dart';

/// Runs code via the public Piston API (emkc.org) — free, no API key,
/// works identically on any platform since execution happens on Piston's
/// servers rather than the student's machine. Tradeoff: code is sent to a
/// third-party service, and the public instance has no uptime SLA — see
/// [LocalProcessService] for the opt-in desktop-only alternative.
class PistonService {
  static const String _baseUrl = 'https://emkc.org/api/v2/piston';

  Future<CodeExecutionResult> run({
    required CodeLanguage language,
    required String code,
    String stdin = '',
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$_baseUrl/execute'));
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );

      final payload = jsonEncode({
        'language': language.pistonLanguage,
        'version': language.pistonVersion,
        'files': [
          {'name': 'main.${language.fileExtension}', 'content': code},
        ],
        'stdin': stdin,
      });
      request.add(utf8.encode(payload));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final decoded = _tryDecode(body);
        final message = (decoded is Map<String, dynamic>)
            ? decoded['message']?.toString() ?? body
            : body;
        throw Exception(
          'Piston request failed (${response.statusCode}): $message',
        );
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;

      final compile = decoded['compile'];
      String? compileError;
      if (compile is Map<String, dynamic>) {
        final compileCode = (compile['code'] as num?)?.toInt() ?? 0;
        if (compileCode != 0) {
          compileError = (compile['stderr']?.toString().trim().isNotEmpty ?? false)
              ? compile['stderr'].toString()
              : 'Compilation failed (exit code $compileCode).';
        }
      }

      final run = decoded['run'];
      if (run is! Map<String, dynamic>) {
        throw Exception('Piston response did not include a run result.');
      }

      return CodeExecutionResult(
        stdout: run['stdout']?.toString() ?? '',
        stderr: run['stderr']?.toString() ?? '',
        exitCode: (run['code'] as num?)?.toInt(),
        compileError: compileError,
      );
    } on SocketException catch (e) {
      throw Exception(
        'Network error while contacting Piston: ${e.message}. '
        'The public Piston instance has no uptime guarantee — try again shortly, or switch to local execution in Settings.',
      );
    } finally {
      client.close(force: true);
    }
  }

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
