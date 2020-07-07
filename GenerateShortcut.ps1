$WshShell = New-Object -comObject WScript.Shell
$psFile = [System.IO.Path]::Combine($PsHome , "powershell.exe")

$rootPath = Split-Path $script:MyInvocation.MyCommand.Path
$srcPath = [System.IO.Path]::Combine($rootPath , "src")
$resourcePath = [System.IO.Path]::Combine($srcPath , "resources")
$icoFile = [System.IO.Path]::Combine($resourcePath , "pChatIcon.ico")
$supportShortcutsPath = [System.IO.Path]::Combine($srcPath , "lnks")


$table = @( @{Variable="psFile";   Value=$psFile},
            @{Variable="rootPath";    Value=$rootPath},
            @{Variable="srcPath";   Value=$srcPath},
            @{Variable="resourcePath";   Value=$resourcePath},
            @{Variable="icoFile";   Value=$icoFile},
            @{Variable="supportShortcutsPath"; Value=$supportShortcutsPath} )

$table | ForEach {[PSCustomObject]$_} | Format-Table -AutoSize

if(!(Test-Path -path $supportShortcutsPath))  {  
    New-Item -ItemType directory -Path $supportShortcutsPath
    Write-Host "Folder path has been created successfully at: " $supportShortcutsPath    
}
else { 
    Write-Host "The given folder path $supportShortcutsPath already exists"; 
}

$shortcutPath = [System.IO.Path]::Combine($rootPath , "pChat.lnk")
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = $psFile
$Shortcut.Arguments = "-windowstyle hidden " + [System.IO.Path]::Combine($srcPath, "LaunchRoomSelection.ps1")
$Shortcut.IconLocation = $icoFile
$Shortcut.Save()

if([System.IO.File]::Exists($shortcutPath)) {
    Write-Host "`nCreation of main shortcut $shortcutPath was successful`n" -ForegroundColor green; 
}
else {
    Write-Error "Failed to create the file $shortcutPath"
}


$shortcutPath = [System.IO.Path]::Combine($supportShortcutsPath , "LaunchRoomCreation.lnk")
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = $psFile
$Shortcut.Arguments = "-windowstyle hidden " + [System.IO.Path]::Combine($srcPath, "LaunchRoomCreation.ps1")
$Shortcut.IconLocation = $icoFile
$Shortcut.Save()

if([System.IO.File]::Exists($shortcutPath)) {
    Write-Host "Creation of shortcut $shortcutPath was successful"-ForegroundColor green; 
}
else {
    Write-Error "Failed to create the file $shortcutPath"
}

$shortcutPath = [System.IO.Path]::Combine($supportShortcutsPath , "LaunchRoom.lnk")
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = $psFile
$Shortcut.Arguments = "-windowstyle hidden " + [System.IO.Path]::Combine($srcPath, "LaunchRoom.ps1")
$Shortcut.IconLocation = $icoFile
$Shortcut.Save()

if([System.IO.File]::Exists($shortcutPath)) {
    Write-Host "Creation of shortcut $shortcutPath was successful"-ForegroundColor green; 
}
else {
    Write-Error "Failed to create the file $shortcutPath"
}

Write-Host "`nDone"; 

Read-Host -Prompt "`nPress Enter to exit"