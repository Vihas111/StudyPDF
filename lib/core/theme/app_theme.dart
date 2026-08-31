import 'package:flutter/material.dart';

import 'app_typography.dart';

/// Light/dark [ThemeData] for StudyPDF, extracted verbatim from
/// `StudyPdfApp.build()` so the composition root in `lib/app.dart` stays
/// small. No visual behavior changes from this extraction.
class AppTheme {
  const AppTheme._();

  static const Color seedColor = Color(0xFF255F85);

  static ThemeData light() {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
    );
    return theme.copyWith(textTheme: AppTypography.textTheme(theme.textTheme));
  }

  static ThemeData dark() {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: seedColor,
      ),
    );
    return theme.copyWith(textTheme: AppTypography.textTheme(theme.textTheme));
  }
}
