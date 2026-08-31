# StudyPDF — Release Notes

---

## v2.0.0 — August 2026

This is the biggest update yet — a free AI tutor, a rebuilt PDF viewer, handwritten-notes import, an embedded code terminal, and a properly optional downloader module.

### ✨ New Features

#### 🤖 Free AI Tutor (OpenRouter)
- **OpenRouter is now the default AI provider** — one free-tier API key instead of juggling separate signups per provider. OpenAI, Groq, Gemini, and Ollama remain available as alternatives.
- The model list is fetched live from OpenRouter's free-tier catalog and is user-selectable in Settings, so it stays current as free models change over time.
- **Cross-Document RAG**: optionally query every open tab at once instead of just the active PDF, useful for comparing content across lectures.

#### 📄 Rebuilt PDF Viewer
- The PDF viewer was rebuilt from scratch as a real document viewport — independent zoom, scroll, and page-layout state — instead of a single image resized to fit the window.
- Zoom now ranges 25%–400% with proper fit-width/custom-zoom modes, instead of being capped at a hard 100% floor.
- Page position tracking is based on each page's actual rendered geometry rather than an estimate, so the page counter no longer flickers while scrolling.
- Only visible pages (plus a small buffer) are rendered at a time, keeping large documents fast.

#### ✍️ Handwritten Notes (Photo Import)
- Import a photo of a handwritten or printed note page and have it transcribed directly into an editable markdown note via a free vision-capable model.
- Diagrams/drawings that aren't transcribable text are detected and can be kept attached as an image alongside the transcribed text.
- A review/edit step is always shown before the transcription is inserted — nothing gets silently trusted.

#### 💻 Embedded Code Terminal
- A new dockable panel for running code (Python, JavaScript, Java, C++) without leaving the app.
- **Piston** (free, external) is the default backend; **local execution** (opt-in, desktop-only, runs via whatever toolchain is already installed) is available as a private alternative in Settings.
- Proper 4-space Tab indentation in the code editor.

#### 🧩 PESU Downloader — Now Optional
- The PESU course-material downloader is now an **off-by-default, opt-in module**, enabled from Settings. Most users of this app aren't PESU students — the Downloads nav entry and its Settings card only appear once explicitly turned on.

#### 📁 First-Run Storage Setup
- New users are now asked where their library should live on first launch, instead of that choice being buried in Settings. The default location works out of the box; existing users upgrading from an earlier version are unaffected and won't see this screen.

#### 📝 Notes Improvements
- Per-page note code blocks now render as a small, monospaced read-only editor view.
- `Ctrl+Enter` saves the current per-page note.
- Every AI Assistant response now has a copy button.

### 🐛 Bug Fixes

- Fixed the PDF viewer squeezing its scrollable canvas down to viewport size, which silently prevented anything beyond roughly one screen's worth of content from ever rendering.
- Fixed zoom being computed from the widest page anywhere in a document (an unusual landscape/scanned page could shrink every normal page); zoom now fits the page actually being viewed.
- Fixed `Ctrl`-modifier state for zoom occasionally getting stuck "pressed" after a window focus change on Windows, which turned plain scrolling into unwanted zooming.
- Fixed deleting a document that was still open in a tab failing with a file-in-use error — the tab now closes (releasing the file handle) before the file is deleted, with a short retry as a safety margin.
- Fixed stale, superseded page renders piling up during rapid zoom changes instead of being cancelled.
- Fixed settings API-key fields cluttering the page with a separate box per provider — consolidated per the active provider selection.
- Fixed a bottom-overflow layout issue when the window is shrunk below full screen.

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
