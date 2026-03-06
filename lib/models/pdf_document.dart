class PdfDocument {
  const PdfDocument({
    required this.id,
    required this.path,
    required this.title,
    required this.lastOpened,
    this.folderPath = '',
    this.thumbnailPath,
    this.progress = 0,
    this.isFavorite = false,
    this.tabColorValue,
  });

  final String id;
  final String path;
  final String title;
  final DateTime lastOpened;
  final String folderPath;
  final String? thumbnailPath;
  final double progress;
  final bool isFavorite;
  final int? tabColorValue;

  PdfDocument copyWith({
    String? id,
    String? path,
    String? title,
    DateTime? lastOpened,
    String? folderPath,
    String? thumbnailPath,
    double? progress,
    bool? isFavorite,
    int? tabColorValue,
    bool clearTabColor = false,
  }) {
    return PdfDocument(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      lastOpened: lastOpened ?? this.lastOpened,
      folderPath: folderPath ?? this.folderPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      progress: progress ?? this.progress,
      isFavorite: isFavorite ?? this.isFavorite,
      tabColorValue: clearTabColor
          ? null
          : (tabColorValue ?? this.tabColorValue),
    );
  }
}
