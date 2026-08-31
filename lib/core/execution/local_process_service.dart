import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:studypdf/core/execution/code_execution_result.dart';

/// Runs code using locally-installed interpreters/compilers via
/// `dart:io Process` — desktop-only, opt-in (arbitrary code execution on
/// the user's own machine is security-sensitive, so this must never be
/// the silent default; the caller gates it behind an explicit settings
/// toggle). Requires the relevant toolchain (python/node/gcc/g++/javac)
/// to already be installed and on PATH; a missing toolchain produces a
/// clear "not installed" error rather than a confusing raw exception.
class LocalProcessService {
  Future<CodeExecutionResult> run({
    required CodeLanguage language,
    required String code,
    String stdin = '',
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('studypdf_code_');
    try {
      switch (language.id) {
        case 'python':
          return await _runInterpreted(
            tempDir: tempDir,
            interpreter: 'python',
            fallbackInterpreter: 'python3',
            code: code,
            extension: 'py',
            stdin: stdin,
          );
        case 'javascript':
          return await _runInterpreted(
            tempDir: tempDir,
            interpreter: 'node',
            code: code,
            extension: 'js',
            stdin: stdin,
          );
        case 'c':
          return await _runCompiled(
            tempDir: tempDir,
            compiler: 'gcc',
            code: code,
            extension: 'c',
            stdin: stdin,
          );
        case 'cpp':
          return await _runCompiled(
            tempDir: tempDir,
            compiler: 'g++',
            code: code,
            extension: 'cpp',
            stdin: stdin,
          );
        case 'java':
          return await _runJava(tempDir: tempDir, code: code, stdin: stdin);
        default:
          throw Exception(
            'Local execution is not supported for ${language.displayName}.',
          );
      }
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // Best-effort cleanup; a locked file (e.g. antivirus scan) is not
        // worth failing the whole run over.
      }
    }
  }

  Future<CodeExecutionResult> _runInterpreted({
    required Directory tempDir,
    required String interpreter,
    String? fallbackInterpreter,
    required String code,
    required String extension,
    required String stdin,
  }) async {
    final file = File(p.join(tempDir.path, 'main.$extension'));
    await file.writeAsString(code);

    try {
      return await _runProcess(interpreter, [file.path], stdin);
    } on _ExecutableNotFoundException {
      if (fallbackInterpreter == null) {
        throw Exception(
          '"$interpreter" is not installed or not on PATH. Install it, or switch to Piston in Settings.',
        );
      }
      try {
        return await _runProcess(fallbackInterpreter, [file.path], stdin);
      } on _ExecutableNotFoundException {
        throw Exception(
          'Neither "$interpreter" nor "$fallbackInterpreter" is installed or on PATH. Install one, or switch to Piston in Settings.',
        );
      }
    }
  }

  Future<CodeExecutionResult> _runCompiled({
    required Directory tempDir,
    required String compiler,
    required String code,
    required String extension,
    required String stdin,
  }) async {
    final sourceFile = File(p.join(tempDir.path, 'main.$extension'));
    await sourceFile.writeAsString(code);
    final outputPath = p.join(
      tempDir.path,
      Platform.isWindows ? 'main.exe' : 'main.out',
    );

    CodeExecutionResult compileResult;
    try {
      compileResult = await _runProcess(compiler, [
        sourceFile.path,
        '-o',
        outputPath,
      ], '');
    } on _ExecutableNotFoundException {
      throw Exception(
        '"$compiler" is not installed or not on PATH. Install it, or switch to Piston in Settings.',
      );
    }

    if (compileResult.exitCode != 0) {
      return CodeExecutionResult(
        stdout: '',
        stderr: '',
        exitCode: compileResult.exitCode,
        compileError: compileResult.stderr.trim().isNotEmpty
            ? compileResult.stderr
            : 'Compilation failed (exit code ${compileResult.exitCode}).',
      );
    }

    return _runProcess(outputPath, const [], stdin);
  }

  Future<CodeExecutionResult> _runJava({
    required Directory tempDir,
    required String code,
    required String stdin,
  }) async {
    final publicClassMatch = RegExp(
      r'public\s+class\s+(\w+)',
    ).firstMatch(code);
    final anyClassMatch = RegExp(r'\bclass\s+(\w+)').firstMatch(code);
    final className =
        publicClassMatch?.group(1) ?? anyClassMatch?.group(1) ?? 'Main';

    final sourceFile = File(p.join(tempDir.path, '$className.java'));
    await sourceFile.writeAsString(code);

    CodeExecutionResult compileResult;
    try {
      compileResult = await _runProcess('javac', [sourceFile.path], '');
    } on _ExecutableNotFoundException {
      throw Exception(
        '"javac" is not installed or not on PATH. Install a JDK, or switch to Piston in Settings.',
      );
    }
    if (compileResult.exitCode != 0) {
      return CodeExecutionResult(
        stdout: '',
        stderr: '',
        exitCode: compileResult.exitCode,
        compileError: compileResult.stderr.trim().isNotEmpty
            ? compileResult.stderr
            : 'Compilation failed (exit code ${compileResult.exitCode}).',
      );
    }

    try {
      return await _runProcess('java', [
        '-cp',
        tempDir.path,
        className,
      ], stdin);
    } on _ExecutableNotFoundException {
      throw Exception(
        '"java" is not installed or not on PATH. Install a JRE/JDK, or switch to Piston in Settings.',
      );
    }
  }

  Future<CodeExecutionResult> _runProcess(
    String executable,
    List<String> args,
    String stdin,
  ) async {
    Process process;
    try {
      process = await Process.start(executable, args);
    } on ProcessException {
      throw const _ExecutableNotFoundException();
    }

    if (stdin.isNotEmpty) {
      process.stdin.write(stdin);
    }
    await process.stdin.close();

    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    final stdoutText = await stdoutFuture;
    final stderrText = await stderrFuture;

    return CodeExecutionResult(
      stdout: stdoutText,
      stderr: stderrText,
      exitCode: exitCode,
    );
  }
}

class _ExecutableNotFoundException implements Exception {
  const _ExecutableNotFoundException();
}
