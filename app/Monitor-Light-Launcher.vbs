Option Explicit

Dim shell
Dim fso
Dim appRoot
Dim scriptPath
Dim logPath
Dim command

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

appRoot = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%\Monitor-Light")
scriptPath = appRoot & "\app\Monitor-Light.ps1"
logPath = appRoot & "\user_profil\Monitor-Light.log"

If Not fso.FolderExists(appRoot & "\user_profil") Then
    fso.CreateFolder(appRoot & "\user_profil")
End If

If Not fso.FileExists(scriptPath) Then
    MsgBox "Monitor-Light.ps1 est introuvable :" & vbCrLf & scriptPath, _
        vbCritical, "Monitor-Light"
    WScript.Quit 1
End If

command = "powershell.exe" & _
    " -NoLogo" & _
    " -NoProfile" & _
    " -ExecutionPolicy Bypass" & _
    " -WindowStyle Hidden" & _
    " -File """ & scriptPath & """" & _
    " 1>>""" & logPath & """" & _
    " 2>>&1"

shell.Run command, 0, False
