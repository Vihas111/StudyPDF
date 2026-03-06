# StudyPDF

A simple Windows application designed for **PES students**.

StudyPDF allows easy downloading of PESU course materials and provides a powerful PDF viewing and AI-assisted study environment.

---

## Features

- Download PESU materials such as **slides, notes, question banks, etc.**
- Built-in **PDF viewer**
- **Note-taking section** for study annotations
- **RAG-based AI doubt clarification system**

### AI Doubt Clarification

The AI system works in two stages:

**1. Document Context Mode**
- Uses the currently viewed document as context
- Retrieves relevant sections
- Generates answers based on the document content

**2. Web Search Mode**
- If the document results are not sufficient
- Enables web search
- Fetches additional information from the internet

---

# Setup Guide

After installation:

1. Open the **Settings** tab from the left panel  
2. Enter **API keys** for the models you want to use  
3. *(Optional)* Enter your **Web Search API key and Engine ID**  
4. If you are a **PES student**, enter your **PESU login credentials**
5. Add your root folder of your choice(this is where all the files get loaded into)

---

# Adding Local Files

1. Go to the **Folder** tab  
2. Add the local folders containing your PDFs  
3. Your study materials will appear in the file explorer

---

# PESU Downloader

StudyPDF includes a downloader for **PESU course materials**.

### Steps

1. Click the **Download icon** on the left  
2. Make sure your **PESU login credentials** are added in Settings  
3. Click **Setup Env**  
4. Click **Load Courses**  
5. Search using **Course Name or Course ID**  
6. Select the course  
7. Click **Load Units**  
8. Select the units you want  
9. Under **Resources**, choose:
   - material type  
   - download format  
10. Click **Start Download**

After downloading:

1. Go to the **Folder Section**  
2. Add the downloaded files to your desired folders

---

# Usage Tips

## Creating Workspaces

Workspaces help open multiple related PDFs together.

**Steps**

1. Press **Shift + Right Click**  
2. Enter a **Workspace Name**  
3. Select the files you want in the workspace  

You can do this in:

- Folder view  
- PDF viewer tabs  

Example:  
Create a workspace for **Unit 1** containing all Unit 1 slides and notes.

---

## Color Coding Tabs

You can color code tabs for easier identification.

**Steps**

1. Right click on a tab  
2. Select a color  

The same color will also appear as the **background color in the folder section**.

---

## Creating Subfolders

To avoid clutter:

- Create **subfolders**
- Organize materials by:
  - subject
  - unit
  - topic

Subfolders appear **nested in the folder view**, making navigation easier.

---

# Quality of Life Features

- **Horizontal scrolling** supported for:
  - tabs
  - recent files section
- Easy workspace management
- Fast PDF navigation

---

# Supported AI Providers

StudyPDF supports:

- **ChatGPT**
- **Gemini**
- **Groq**

Simply add the corresponding **API keys in Settings**.
