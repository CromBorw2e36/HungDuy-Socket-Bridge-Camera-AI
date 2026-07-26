' VBScript to start Face Recognition Server completely hidden
' This script runs Python without any visible windows

Dim objShell, objFSO, strScriptDir, strProjectDir, strPythonFile

' Get the directory where this script is located
strScriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
strProjectDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(strScriptDir)
strPythonFile = strProjectDir & "\main_api_cam.py"

' Check if the Python file exists
Set objFSO = CreateObject("Scripting.FileSystemObject")
If Not objFSO.FileExists(strPythonFile) Then
    WScript.Quit 1
End If

' Create shell object
Set objShell = CreateObject("WScript.Shell")

' Change to project directory and run Python script completely hidden
objShell.CurrentDirectory = strProjectDir
objShell.Run "pythonw.exe main_api_cam.py", 0, False

' Clean up and exit
Set objShell = Nothing
Set objFSO = Nothing
WScript.Quit 0