$rootPath = Split-Path $script:MyInvocation.MyCommand.Path
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$rootPath\pChat.lnk")
$Shortcut.TargetPath = "$PsHome\powershell.exe"
$Shortcut.Arguments = "-windowstyle hidden $rootPath\src\LaunchRoomSelection.ps1"
$Shortcut.IconLocation = "$rootPath\src\resources\pChatIcon.ico"
$Shortcut.Save()

$Shortcut = $WshShell.CreateShortcut("$rootPath\src\lnks\LaunchRoomCreation.lnk")
$Shortcut.TargetPath = "$PsHome\powershell.exe"
$Shortcut.Arguments = "-windowstyle hidden $rootPath\src\LaunchRoomCreation.ps1"
$Shortcut.IconLocation = "$rootPath\src\resources\pChatIcon.ico"
$Shortcut.Save()

$Shortcut = $WshShell.CreateShortcut("$rootPath\src\lnks\LaunchRoom.lnk")
$Shortcut.TargetPath = "$PsHome\powershell.exe"
$Shortcut.Arguments = "-windowstyle hidden $rootPath\src\LaunchRoom.ps1"
$Shortcut.IconLocation = "$rootPath\src\resources\pChatIcon.ico"
$Shortcut.Save()