Dim objShell, objFSO, dir
Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
dir = objFSO.GetParentFolderName(WScript.ScriptFullName)
objShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & dir & "\self-destruct.ps1""", 0, False
