# StudyPDF

A simple windows application designed for PES students:
-Allows easy downloading of pesu material like slides, notes, QB, etc..
-Has an easy to use pdf viewer along with note taking section and a RAG implimentation for AI doubt clarification
-The AI doubt clarification has 2 stages.
    a) Uses the viewed document to obtain context and return results that clarify doubts
    b) if results are not satisfactory enabling web search mode allows assistant to access the web and obtain results

Steps to use:
-Once installation is done head to settings tab on the left
-Enter your api keys for the models you wish to use
-(optional)Enter your web search api key and engine id
-(pes student)Enter PESU login details
-Head over to folder tab and add your local folders
-Click on the download icon on the left to download pesu course materials(pesu downloader)
  -ensure you have added your login credentials in the settings tab
  -click on setup env
  -then click on load courses
  -then enter the course name or id in the search bar
  -after selecting course click on load units and select the units which you want
  -next under resources select the material and download format that you want and click on start download
-After download has been completed succesfully head to folder section and add the files which you would like into the folders you want



Usage tips:
Create workspaces by -> shift+right click and enter workspace name: then select all the files you want to put in the same workspace
This allows you to launch all files at the same time(so u can place all files from a single unit into 1 workspace
You can do this either in the folder section or in the pdf viewer section by shift+right click on a tab

Color code tabs:
This makes it clearer and easier to mark tabs and files by right clicking on a tab(the same color will also be applied as a bg color for the file in the folder section)

Create sub folders:
Dont clutter files into a single folder sub folders will appear nested in the folder view section to help you organise your files



Some Quality of Life features:
Horizontal scrolling on tabs and recent files section is supported
Support for Chatgpt, Gemini and Groq has been implemented


