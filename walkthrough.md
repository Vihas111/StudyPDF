# Welcome to StudyPDF!

StudyPDF is designed to make reading, annotating, and understanding your course materials as seamless as possible. Here is a quick guide to help you get the most out of the application.

---

## 0. First Launch: Choosing Your Library Location

The very first time you open StudyPDF, you'll be asked where your library — PDFs, notes, and imports — should be stored.

- **Use the default location**: works out of the box, no action needed.
- **Choose a Different Folder…**: pick any folder on your machine (e.g. a synced OneDrive/Drive folder).
- You can change this later at any time from **Settings ⚙️ → Change Root Directory**.

> [!NOTE]
> If you're upgrading from an earlier version of StudyPDF and already had a library location configured, you won't see this screen again — your existing setup is carried over automatically.

---

## 1. Main Folder Library
The first screen you see is the **Document Library**, which acts as home base for all your study materials.

- **Add Local PDFs**: Click the button in the top right to import new PDFs into your library.
- **Folder Organization**: Create folders using the "New Folder" button on the left panel to organize your courses or subjects. Select a folder to view only the PDFs inside it.
- **Recent Files**: A horizontal strip shows your most recently opened documents for quick access.
- **Grid/List View**: Toggle between a visual Grid view and a condensed List view using the segmented button next to the import option.
- **Reading Progress**: Each PDF card displays a progress bar showing how much of the document you've read, along with when you last opened it.
- **Workspace Shortcuts**: You can create custom workspaces by Right-Clicking (or tapping and holding) a PDF, turning a specific set of documents into a saved shortcut.

---

## 2. Managing PDF Viewer Section
The PDF viewer is a real document viewport — independent zoom (25%–400%), scrolling, and page tracking based on each page's actual geometry — rather than an image stretched to fit the window. It consists of 4 segments

- **Tab Segment**: Manage open documents and workspaces.
- **PDF Workspace (Center)**: Your active document viewer.
- **AI Assistant**: A built-in LLM chat interface to help explain concepts.
- **Notes Editor**: A Markdown-based note-taking area tied directly to the document you are reading.

**Organizing Tabs (Shift+Right-Click):**
- **Shift + Right-Click a Tab**: Creates a Workspace
- **Right-Click a tab**: Allows you to 
  - Merge Notes 
  - Change Document and tab color
- **Shift + Right-Click a Workspace**: Allows you to quickly edit the Documents inside the workspace
- **Right-Click a Workspace**: Allows you to 
  - Change Workspace Name
  - Change Document in the Workspace
  - Merge Notes
  - Close tabs
  - Delete Workspace

> [!TIP]
> **Customizing Layout**: You can change where these panels appear (Left, Right, Bottom) or disable them entirely by clicking the ⚙️ **Settings gear** in the top right.

## 3. API Keys & AI Assistant
To use the AI Assistant, you must configure an API key for your preferred provider.

1. Click the **Settings ⚙️** icon in the top right.
2. Scroll to **AI Settings**.
3. Choose your **Default Provider** — **OpenRouter is the default and free**, giving you access to a rotating catalog of free-tier models with just one API key. OpenAI, Groq, Gemini, and local Ollama are also available if you prefer a direct key.
4. Enter your API key for that provider and press Enter or the Save icon.
5. If you picked OpenRouter, you can also choose which free model to use from the live-fetched model list.

Once configured, simply highlight text in your PDF, or type a question directly into the Assistant panel like *"Can you simplify this page for me?"*

## 4. 🆕 Cross-Document RAG (Search All Tabs)
By default, the AI Assistant only reads the PDF tab you currently have open. If you want the AI to synthesize information across **multiple PDFs at once** (e.g., comparing Lecture 1 with Lecture 3):

1. Go to **Settings ⚙️ > AI Settings**.
2. Toggle on **Query all open tabs (Cross-Document RAG)**.
3. Open all the PDFs you want to compare into separate tabs.
4. Ask your question! The AI will now pull the most relevant chunks of text from *all* your open documents and cite which document it used.


> [!NOTE]
> Web Search fallback is also available in settings! If the PDF doesn't contain the answer, the AI can search Google (requires a Custom Search API Key).
> Querying across multiple tabs will increase the number of tokens used and the time taken to return results.
## 5. Merged Notes
As you read and annotate PDFs, your notes are saved page-by-page. StudyPDF allows you to compile all these individual notes into a single cohesive document.

1. When in the pdf viewer section right click on a document tab or workspace tab then select merge notes.
2. Click the **Notes 📝** icon on the left navigation rail to open the **Merged Notes Library**.
3. Here, you can view all your compiled notes across different documents and workspaces.
4. Right-Click on a merged note allows:
   - Edit note
   - Export Note as a pdf or a markdown(.md)
   - Delete note

## 6. Handwritten Notes (Photo Import)
Turn a photo of a handwritten (or printed) note page into a real, editable note.

1. In the note editor, use the **Import handwritten note** option and select or paste a photo.
2. StudyPDF transcribes the legible text using a free vision-capable AI model.
3. Review the transcribed text (and any diagram detected as non-text content) before inserting — nothing is inserted automatically without your confirmation, since transcription isn't always perfect.
4. Once confirmed, the text is inserted as normal, editable markdown; any diagram is kept as an attached image.

## 7. Embedded Code Terminal
Test code from a textbook example without leaving the app.

1. Open the **Code Terminal** panel from the workspace.
2. Pick a language (Python, JavaScript, Java, or C++), write or paste code, and press **Run**.
3. By default, code runs via **Piston** (a free external execution service) — no local install needed.
4. If you'd rather nothing leave your machine, switch to **Local execution** in **Settings ⚙️ → Code Execution**, which uses whatever interpreter/compiler is already installed on your computer.

## 8. Course Downloader (Optional)
StudyPDF includes an optional module for fetching PESU course materials directly. It's **off by default** — most users aren't PESU students — so you'll need to turn it on first.

1. Go to **Settings ⚙️** and enable **PESU Course Downloader**. A new **Download 📥** icon appears on the left navigation rail.
2. Click the **Download 📥** icon.
3. Enter your PESU credentials in the Settings page if you haven't already.
4. Click "Fetch Courses" and select the materials you need. They will be downloaded and automatically imported into your local library.


Thanks for trying it out!!
