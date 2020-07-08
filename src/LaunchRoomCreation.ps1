#
# .\LaunchRoomCreation
#

using namespace System.Collections.Concurrent

# Not needed when run from ISE, but is if straight PS
Add-Type -AssemblyName PresentationFramework

# gets the root folder containing this script.
# depending on how this script is run, the exact way to get this changes
Function Get-PChatRoot {
    if ($psise) {
        $pchatRoot = Split-Path $psise.CurrentFile.FullPath
    }
    else {
        $pchatRoot = Split-Path $PSCommandPath
    }

    return $pchatRoot
}

# Generate a random Alphanumeric string
Function Get-RandomAlphanumericString {
	
	[CmdletBinding()]
	Param (
        [int] $length = 5
	)

	Begin{
	}

	Process{
        Write-Output ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count $length  | ForEach-Object {[char]$_}) )
	}	
}

# room selection can be single-threaded.  no need to mess with runspaces here
$pchatRoot = Get-PChatRoot

$roomCreationXamlFile =  [System.IO.Path]::Combine($pchatRoot , "xaml", "RoomCreationForm.xaml")

$xaml = [xml](Get-Content -Path $roomCreationXamlFile)
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# add icon
$window.add_Loaded({
    $window.Icon = [System.IO.Path]::Combine($pchatRoot , "resources", "pChatIcon.ico")
})

# populate the rooms
$roomName = $window.FindName("RoomName")

# wire up the Join Room button
$joinRoomButton = $window.FindName("JoinRoomButton")
$randomVal = (Get-RandomAlphanumericString | Tee-Object -variable teeTime).ToLower()
$joinRoomButton.Add_Click({
   $selectedRoom = $roomName.Text
   If ([string]::IsNullOrEmpty($selectedRoom)) {
        Write-Host "Value " + $randomVal
        $selectedRoom = $randomVal
        Write-Host "Value " + $selectedRoom
   }
   if($selectedRoom -match '[^\w\s-_]') {
        [System.Windows.MessageBox]::Show("Please do not use any special characters except - and _ in your room name.",'Invalid Input','OK','Error')
   }
   else {
       $selectedRoom = $selectedRoom -replace ' ',[Regex]::Escape('%20')
       Start-Process powershell -ArgumentList "$($pchatRoot)\lnks\LaunchRoom.lnk '$selectedRoom'" -windowstyle hidden
       stop-process -Id $PID
   }
}.GetNewClosure())

$roomTextbox = $window.FindName("RoomName")
$roomTextbox.Add_KeyDown({
    if ($_.Key -eq "Enter" -or $_.Key -eq "Return") {
        $joinRoomButton.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)));
    }
}.GetNewClosure())

$window.ShowDialog()