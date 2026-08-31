/// Shared design tokens for the StudyPDF desktop UI.
///
/// Centralizing spacing/radii/elevation here keeps future panel work
/// (Phase 1 UI overhaul) consistent instead of every screen picking its
/// own ad hoc numbers.
library;

/// Spacing scale (logical pixels). Prefer these over magic numbers when
/// touching layout code.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Corner-radius scale (logical pixels).
class AppRadii {
  const AppRadii._();

  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
}

/// Elevation scale, matching Material 3 surface tint levels.
class AppElevation {
  const AppElevation._();

  static const double none = 0;
  static const double low = 1;
  static const double medium = 3;
  static const double high = 6;
}
