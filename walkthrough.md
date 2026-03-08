# Welcome to StudyPDF!

StudyPDF is designed to make reading, annotating, and understanding your course materials as seamless as possible. Here is a quick guide to help you get the most out of the application.

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
Your PDF viewer consists of 4 segments

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
3. Choose your **Default Provider** (OpenAI, Groq, Gemini, or local Ollama). 
4. Enter your API key for that provider and press Enter or the Save icon.

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

## 6. Course Downloader
StudyPDF includes a built-in module for fetching course materials directly.
1. Click the **Download 📥** icon on the left navigation rail.
2. Enter your credentials in the Settings page if you haven't already.
3. Click "Fetch Courses" and select the materials you need. They will be downloaded and automatically imported into your local library.


Thanks for trying it out!!
