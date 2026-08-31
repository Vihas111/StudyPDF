import 'package:flutter/material.dart';

/// A [TextTheme] tuned for dense desktop information display (PDF pages,
/// notes, settings forms) rather than mobile-first defaults.
///
/// This does not change the app's visual output from before the Phase 0
/// refactor — [ColorScheme.fromSeed] combined with Material 3's default
/// text theme already produced these exact styles implicitly. This class
/// exists so later phases have a single place to tune desktop typography
/// without hunting through `app.dart`.
class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(TextTheme base) => base;
}
