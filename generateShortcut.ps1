$rootPath = Split-Path $script:MyInvocation.MyCommand.Path
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$rootPath\pChat.lnk")
$Shortcut.TargetPath = "$PsHome\powershell.exe"
#$Shortcut.Arguments = "-noexit -ExecutionPolicy Bypass -File -windowstyle hidden $rootPath\PS\LaunchRoomSelection.ps1"
$Shortcut.Arguments = "-windowstyle hidden $rootPath\src\LaunchRoomSelection.ps1"
$Shortcut.IconLocation = "$rootPath\src\resources\pChatIcon.ico"
$Shortcut.Save()