import 'dart:convert';

class WorkspaceShortcut {
  const WorkspaceShortcut({
    required this.id,
    required this.name,
    required this.tabPaths,
    this.colorValue,
  });

  final String id;
  final String name;
  final List<String> tabPaths;
  final int? colorValue;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tabPaths': tabPaths,
      'colorValue': colorValue,
    };
  }

  static WorkspaceShortcut fromJson(Map<String, dynamic> json) {
    return WorkspaceShortcut(
      id: json['id'] as String,
      name: json['name'] as String,
      tabPaths: (json['tabPaths'] as List<dynamic>).cast<String>(),
      colorValue: json['colorValue'] as int?,
    );
  }

  static String encodeList(List<WorkspaceShortcut> shortcuts) {
    return jsonEncode(shortcuts.map((s) => s.toJson()).toList(growable: false));
  }

  static List<WorkspaceShortcut> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(WorkspaceShortcut.fromJson)
        .toList(growable: false);
  }
}

class ShortcutLaunchRequest {
  const ShortcutLaunchRequest({
    required this.name,
    required this.tabIds,
    required this.nonce,
    this.colorValue,
  });

  final String name;
  final List<String> tabIds;
  final int nonce;
  final int? colorValue;
}
