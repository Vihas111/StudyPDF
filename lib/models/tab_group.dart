class TabGroup {
  const TabGroup({
    required this.id,
    required this.name,
    required this.tabIds,
    this.colorValue,
    this.isCollapsed = false,
  });

  final String id;
  final String name;
  final List<String> tabIds;
  final int? colorValue;
  final bool isCollapsed;

  TabGroup copyWith({
    String? id,
    String? name,
    List<String>? tabIds,
    int? colorValue,
    bool? isCollapsed,
  }) {
    return TabGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      tabIds: tabIds ?? this.tabIds,
      colorValue: colorValue ?? this.colorValue,
      isCollapsed: isCollapsed ?? this.isCollapsed,
    );
  }
}
