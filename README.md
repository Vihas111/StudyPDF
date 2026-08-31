# StudyPDF

StudyPDF is a **Windows desktop application** for reading PDFs, taking structured notes, and studying with a free built-in AI tutor — all in one workspace.

It combines a **custom-built PDF viewer, a Notion-like note system, an embedded code terminal, and an AI assistant** into a single study tool.

---

# Features

## PDF Library and Viewer

* A **from-scratch PDF viewport** (not a bitmap stretched to fit the window) — real zoom (25%–400%), independent scrolling, and page tracking based on actual page geometry, matching how desktop/browser PDF viewers behave.
* Workspace-based **tab groups** for reading multiple related PDFs together
* Fast navigation between files, with color-coded tabs for easy identification
* Reading-progress tracking per document

---

## AI Study Assistant

StudyPDF includes a **free-by-default AI assistant** to help explain concepts and answer questions about your study material.

* **OpenRouter is the default provider** — one free API key gives access to a rotating catalog of free-tier models, so there's no separate signup or paid key required to get started. OpenAI, Groq, Gemini, and local Ollama remain available as alternative providers if you prefer a direct key.
* **Stage 1 — Document Context**: retrieves relevant sections from the PDF you're reading and grounds its answer in that content.
* **Stage 2 — Web Search fallback**: if the document doesn't contain enough information, StudyPDF can fall back to a web search (requires a Google Custom Search API key + Engine ID, configured in Settings).
* **Cross-Document RAG**: optionally query across every open tab at once (e.g. comparing Lecture 1 with Lecture 3), instead of just the currently active PDF.

### Supported AI Providers

| Provider                | Notes                                         |
| ------------------------ | ---------------------------------------------- |
| **OpenRouter** (default) | Free-tier models, one API key, no separate signup per model |
| **OpenAI (ChatGPT)**      | Requires OpenAI API key                       |
| **Gemini**                | Requires Gemini API key                       |
| **Groq**                  | Requires Groq API key                         |
| **Ollama**                | Local, requires Ollama running on your machine |

Enter the required **API key(s) in Settings**.

---

## Handwritten Notes (Photo Import)

Import a photo of a handwritten (or printed) note page and have it transcribed straight into a real, editable note:

* Uses a free vision-capable OpenRouter model to transcribe the page
* Transcribed text becomes normal, editable markdown — not a picture of text
* If the page contains a diagram or drawing that isn't transcribable, you're offered the option to keep the original photo attached alongside the text
* Always shows a **review/edit step** before inserting — transcription errors happen, so nothing is inserted silently

---

## Embedded Code Terminal

A dockable "run code while reading" panel for testing code without leaving your textbook:

* Syntax-highlighted editor (Python, JavaScript, Java, C++) with proper Tab indentation
* **Piston** (free, external, default) — runs code on a public execution service, no local toolchain required
* **Local execution** (opt-in, desktop-only) — runs code with whatever interpreters/compilers are already installed on your machine, so nothing leaves your device; switch between the two in Settings

---

# Note-Taking System

StudyPDF provides a **Notion-like note-taking workflow** integrated with your PDFs.

## Per-Page Notes

Each PDF page can have its own markdown note. Open a PDF, use the **Notes panel**, and write notes linked to that page. Code blocks in notes render as a small, monospaced read-only editor view, and `Ctrl+Enter` saves.

---

## Merge Notes (Document Level)

Right-click a **PDF tab → Merge Notes**. This creates a **Master Note** containing:

* All page notes
* An auto-generated **Agenda** with anchor links to each section

---

## Merge Notes (Workspace Level)

Right-click a **Workspace / Tab Group → Merge Notes** to combine notes across multiple PDFs into one Master Note, organized Document → Page.

---

## Notes Library

Access all merged notes from the **Notes** section in the navigation rail. View, edit, export, or delete notes from there.

---

## Two-Way Sync

Merged notes are **fully synchronized** with page notes. Editing a merged note (or adding a `### Page N` section) automatically updates the corresponding page note.

---

## Export Notes

Notes can be exported as:

* **Markdown (.md)**
* **PDF Document (.pdf)** — proper heading sizes, rendered lists/code blocks, and clean text

Right-click a note and select **Export**.

---

# First-Run Setup

The first time you launch StudyPDF, you'll be asked where your library (PDFs, notes, imports) should live — accept the default location or pick your own folder. This can be changed later at any time from **Settings → Change Root Directory**.

After that:

1. Open **Settings**
2. Enter an **API key** for your preferred AI provider (OpenRouter needs just one, and it's free)
3. *(Optional)* Add a **Web Search API key and Engine ID** for the search fallback
4. *(Optional)* If you're a **PES student**, enable the **PESU Course Downloader** (see below) and add your credentials

---

# Adding Local Files

1. Open the **Folder section**
2. Add folders containing your PDFs
3. StudyPDF will index them in the library

---

# PESU Downloader (Optional)

The PESU course-material downloader is an **off-by-default, opt-in module** — most users of this app aren't PESU students, so it stays out of the way unless you turn it on.

For more information, check out the underlying repository:
https://github.com/ilb225112/pesu_course_downloader

### Enabling it

1. Go to **Settings → Enable PESU Course Downloader**
2. A **Downloads** section appears in the navigation rail
3. Enter your **PESU credentials** in Settings
4. Click **Setup Env**, then **Load Courses**
5. Search by **Course Name or Course ID**
6. Select a course → **Load Units**, select units to download
7. Choose **material type** and **download format**, then **Start Download**

After downloading, add the files to your library from the **Folder section**.

---

# Usage Tips

## Creating Workspaces

1. **Shift + Right Click** files in the folder view
2. Enter a **Workspace Name**
3. Select the PDFs to include

Example: create a workspace for **Unit 1** containing all Unit 1 slides and notes.

---

## Color Coding Tabs

Right-click a tab and select a color — the same color appears in the folder view.

---

## Creating Subfolders

Organise materials by subject, unit, or topic — subfolders appear nested in the folder explorer.

---

# Quality of Life

* Horizontal scrolling for tabs and recent files
* Workspace shortcuts on the home screen
* External pop-out windows for AI and Notes
* Resizable, collapsible Folders panel
* Configurable AI/Notes panel docking (left, right, or bottom)

---

# Installation

Download the latest installer from the **Releases page**.

Run:

```
StudyPDF-Setup-v2.0.0.exe
```

Follow the installation wizard. If you already have StudyPDF installed, `StudyPDF-Updater-v2.0.0.exe` patches an existing install in place.

---

# Releases

See [RELEASE_NOTES.md](RELEASE_NOTES.md) or the **GitHub Releases page** for the full changelog.

---

# License

This project is intended for educational use.
