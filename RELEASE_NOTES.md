# StudyPDF — Release Notes

---

## v1.1.0 — March 2026

### ✨ New Features

#### 📝 Notion-Like Merged Notes
- **Per-Page Notes**: Write markdown notes on any page of any open PDF. Notes are saved per-document, per-page automatically.
- **Merge Notes (Per Document)**: Right-click any PDF tab and select **Merge Notes** to compile all your page notes into a single unified Markdown document with a clickable Agenda at the top.
- **Merge Notes (Workspace-Level)**: Right-click a **Tab Group / Workspace chip** to merge notes across every PDF in that workspace into one Master Note. The Agenda is hierarchically organised by Document → Page Number.
- **Markdown Editor**: Merged Notes open in a dedicated full-screen editor with live **Edit / Preview** toggle powered by `flutter_markdown`.
- **Smart Anchor Scrolling**: Clicking an Agenda index link auto-scrolls to the correct document or page section within the editor.
- **Rename Notes**: Click the edit icon next to the title in the editor to rename any merged note at any time.

#### 📚 Notes Library
- A new **Notes** section (pen icon) in the Navigation Rail displays all saved Merged Notes.
- Right-click any note card to **Edit** (re-opens in workspace as a tab) or **Delete**.

#### 🔄 Two-Way Note Syncing
- Edits made inside a Merged Note are automatically synced back to the individual PDF page notes when you save.
- Add new `### Page N` headings under a Document section and they will be created as fresh page notes instantly.

#### 📤 Note Export
- Right-click any note in the Notes Library and select **Export Note**.
- Choose between:
  - **Markdown (.md)** — exports the raw markdown file.
  - **PDF Document (.pdf)** — exports a formatted, paginated PDF with proper heading sizes and clean text (links and markdown syntax stripped automatically).

---

### 🐛 Bug Fixes

- **AI Provider Registry**: Fixed a critical bug where changing the AI provider (Groq, Gemini, Ollama) would silently fall back to OpenAI. All four providers — OpenAI, Groq, Gemini, and Ollama — now route correctly to their respective APIs.
- **Notes Sync**: The Notes Library now refreshes automatically when a new note is saved from the workspace.
- **PDF Export Stability**: Resolved a crash in the Syncfusion PDF layout engine caused by zero-height bounds and unicode characters in exported text.

---

## v1.0.0 — Initial Release

- PDF library viewer and reader with workspace tab groups.
- AI Assistant panel supporting OpenAI, Groq, Gemini, and Ollama.
- PESU Course Downloader integration.
- Workspace preferences and settings.
- Multi-window external AI and Notes panels.
