# Flutter Windows App Design Rules

## Tech Stack & Architecture
- Framework: Flutter Desktop (Windows), Material 3, no third-party state management (plain `StatefulWidget`/`setState`)
- Multi-window support: `desktop_multi_window`
- PDF rendering: `syncfusion_flutter_pdf` / `syncfusion_flutter_pdfviewer`
- Markdown rendering: `flutter_markdown_plus`
- No dedicated windowing/title-bar package (`bitsdojo_window`, `window_manager`) or Fluent UI dependency is present — don't assume APIs from either without adding the dependency first.

## Windows UI/UX Constraints
- Never use fixed mobile heights/widths. Use flexible, expanded, and adaptive layout grids (`LayoutBuilder`, `Expanded`, `Flexible`).
- Implement explicit hover states (`MouseRegion`) for all interactive elements — this is a desktop app driven by mouse, not touch.
- Avoid generic web fonts. Use clear desktop typography scales appropriate to dense information display (PDF/notes content).
- Respect window resizing: layouts must reflow correctly across a wide range of window sizes, not just a fixed design width — this matters especially for `merged_note_editor_panel.dart` and other split-pane views.
- Support mouse wheel scrolling everywhere scrollable content appears.

## Notes
- Keep this file in sync with `pubspec.yaml` and `lib/` as dependencies change (e.g. if a windowing or state-management package is added later).
