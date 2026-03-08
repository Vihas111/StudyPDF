# StudyPDF

StudyPDF is a **Windows desktop application designed for PES students** to manage course materials, read PDFs efficiently, take structured notes, and clarify doubts using AI.

It combines a **PDF reader, workspace-based study environment, and RAG-powered AI assistant** into one tool for a streamlined study workflow.

---

# Features

## Course Material Downloader

Download **PESU course resources** such as:

* Slides
* Notes
* Question banks
* Other course materials

All downloaded files can be automatically organised inside your StudyPDF library.

---

## PDF Library and Viewer

* Built-in **PDF reader**
* Workspace-based **tab groups**
* Fast navigation between files
* Color-coded tabs for easy identification

Workspaces allow you to open **multiple related PDFs together**, making it easy to study entire units at once.

---

# AI Doubt Clarification

StudyPDF includes a **RAG-powered AI assistant** to help answer questions about your study material.

### Stage 1 — Document Context

* Uses the currently viewed PDF as context
* Retrieves relevant sections using **RAG**
* Generates answers grounded in the document

### Stage 2 — Web Search

If the document does not contain enough information:

* Web search is automatically used
* Additional information is retrieved from the internet

---

# Supported AI Providers

StudyPDF allows you to choose your preferred AI provider.

| Provider             | Notes                             |
| -------------------- | --------------------------------- |
| **OpenAI (ChatGPT)** | Requires OpenAI API key           |
| **Gemini**           | Requires Gemini API key           |
| **Groq**             | Requires Groq API key             |

Simply enter the required **API keys in Settings**.

---

# Note-Taking System

StudyPDF provides a **Notion-like note-taking workflow** integrated with your PDFs.

## Per-Page Notes

Each PDF page can have its own markdown note.

* Open a PDF
* Use the **Notes panel**
* Write markdown notes linked to that page

---

## Merge Notes (Document Level)

Right-click a **PDF tab → Merge Notes**

This creates a **Master Note** containing:

* All page notes
* An auto-generated **Agenda**
* Links to each page section

---

## Merge Notes (Workspace Level)

Right-click a **Workspace / Tab Group → Merge Notes**

This creates a **Master Note** that combines notes across multiple PDFs.

Structure:

```
Document
 ├ Page 1
 ├ Page 2
 └ Page 3
```

---

## Notes Library

Access all merged notes from the **Notes section** in the navigation bar.

You can:

* View notes
* Edit notes
* Export notes
* Delete notes

---

## Two-Way Sync

Merged notes are **fully synchronized** with page notes.

If you:

* Edit a merged note
* Add a `### Page N` section

StudyPDF automatically updates the corresponding **page note**.

---

## Export Notes

Notes can be exported as:

* **Markdown (.md)**
* **PDF Document (.pdf)**

Simply right-click a note and select **Export**.

---

# Setup Guide

After installing StudyPDF:

1. Open the **Settings** tab
2. Enter **API keys** for your preferred AI providers
3. *(Optional)* Add a **Web Search API key and Engine ID**
4. If you are a **PES student**, add your **PESU login credentials**
5. Choose a **root library folder** where all PDFs will be stored

---

# Adding Local Files

1. Open the **Folder section**
2. Add folders containing your PDFs
3. StudyPDF will index them in the library

---

# PESU Downloader

StudyPDF includes an integrated downloader for **PESU course materials**.
For more information checkout the following repository:
https://github.com/ilb225112/pesu_course_downloader

### Steps

1. Click the **Download icon**
2. Ensure your **PESU credentials** are saved
3. Click **Setup Env**
4. Click **Load Courses**
5. Search using **Course Name or Course ID**
6. Select a course → Click **Load Units**
7. Select units to download
8. Choose:

   * material type
   * download format
9. Click **Start Download**

After downloading, add the files to your library from the **Folder section**.

---

# Usage Tips

## Creating Workspaces

Workspaces allow you to group related PDFs.

Steps:

1. **Shift + Right Click** files in the folder view
2. Enter a **Workspace Name**
3. Select the PDFs to include

Example:

Create a workspace for **Unit 1** containing all Unit 1 slides and notes.

---

## Color Coding Tabs

Tabs can be color coded for quick identification.

Steps:

1. Right-click a tab
2. Select a color

The same color will also appear in the **folder view**.

---

## Creating Subfolders

To organise your materials:

* Create **subfolders**
* Organise by:

  * subject
  * unit
  * topic

Subfolders appear nested in the folder explorer.

---

# Quality of Life

* Horizontal scrolling for tabs and recent files
* Workspace shortcuts on the home screen
* Fast PDF navigation
* External pop-out windows for AI and Notes

---

# Installation

Download the latest installer from the **Releases page**.

Run:

```
StudyPDF-v1.2.0-windows-Setup.exe
```

Follow the installation wizard.

---

# Releases

See the **GitHub Releases page** for updates and new features.

---

# License

This project is intended for educational use.
