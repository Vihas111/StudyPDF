# StudyPDF

## Build Windows EXE Installer

Use the packaging script:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\windows\build_installer.ps1
```

This script:
- builds Flutter Windows `Release` binaries
- stages only required app/runtime files
- stages only required `pesu_course_downloader` source files
- excludes local/generated data (`venv`, cache, and downloaded files)
- runs Inno Setup (if installed) to create `StudyPDF-Setup.exe`

Installer output:

```text
build\installer\dist\StudyPDF-Setup.exe
```

## Privacy / Data Exclusion

The installer does not package your local user configurations such as:
- AI API keys
- web search keys
- PESU credentials
- recent files / workspace runtime preferences

These are stored by the app in user profile storage (`SharedPreferences`) at runtime, not in installer assets.

The installer also excludes PESU downloader local content:
- `pesu_course_downloader\venv\`
- `pesu_course_downloader\downloads\`
