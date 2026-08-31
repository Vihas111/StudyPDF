/// Result of running a code snippet, from either backend (Piston or local).
class CodeExecutionResult {
  const CodeExecutionResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    this.compileError,
  });

  final String stdout;
  final String stderr;
  final int? exitCode;

  /// Non-null if a compile step (C/C++/Java) failed before the program
  /// ever ran.
  final String? compileError;

  bool get succeeded => compileError == null && (exitCode == null || exitCode == 0);
}

/// A supported language for the code terminal panel.
class CodeLanguage {
  const CodeLanguage({
    required this.id,
    required this.displayName,
    required this.highlightMode,
    required this.pistonLanguage,
    required this.pistonVersion,
    required this.fileExtension,
  });

  /// Stable id used for persisting the user's language choice.
  final String id;
  final String displayName;

  /// Key into the `highlight` package's language registry (e.g. 'python').
  final String highlightMode;

  /// Piston's language id and pinned version (Piston requires an exact
  /// version match against its /runtimes list).
  final String pistonLanguage;
  final String pistonVersion;

  final String fileExtension;
}

/// Curated set of languages relevant to a study tool — not Piston's full
/// catalog, which is much larger. Versions verified against Piston's
/// public /runtimes endpoint at implementation time; Piston pins runtime
/// versions per-language so these rarely change, but if a version here
/// ever stops matching, PistonService surfaces the API's error message
/// directly rather than failing silently.
const List<CodeLanguage> kSupportedCodeLanguages = [
  CodeLanguage(
    id: 'python',
    displayName: 'Python',
    highlightMode: 'python',
    pistonLanguage: 'python',
    pistonVersion: '3.10.0',
    fileExtension: 'py',
  ),
  CodeLanguage(
    id: 'javascript',
    displayName: 'JavaScript',
    highlightMode: 'javascript',
    pistonLanguage: 'javascript',
    pistonVersion: '18.15.0',
    fileExtension: 'js',
  ),
  CodeLanguage(
    id: 'java',
    displayName: 'Java',
    highlightMode: 'java',
    pistonLanguage: 'java',
    pistonVersion: '15.0.2',
    fileExtension: 'java',
  ),
  CodeLanguage(
    id: 'c',
    displayName: 'C',
    highlightMode: 'cpp',
    pistonLanguage: 'c',
    pistonVersion: '10.2.0',
    fileExtension: 'c',
  ),
  CodeLanguage(
    id: 'cpp',
    displayName: 'C++',
    highlightMode: 'cpp',
    pistonLanguage: 'c++',
    pistonVersion: '10.2.0',
    fileExtension: 'cpp',
  ),
];
