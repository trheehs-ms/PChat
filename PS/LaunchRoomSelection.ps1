#
# .\LaunchRoomSelection
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

Function Get-Rooms {
    $pchatRoot = Get-PChatRoot

    # TODO: would be cool if we only listed ones the user has RW access to
    Get-ChildItem -Directory "$($pchatRoot)\..\rooms" | %{ $_.Name }
}


# room selection can be single-threaded.  no need to mess with runspaces here
$pchatRoot = Get-PChatRoot

$roomSelectionXamlFile =  [System.IO.Path]::Combine($pchatRoot , "xaml", "RoomSelectionForm.xaml")

$xaml = [xml](Get-Content -Path $roomSelectionXamlFile)
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# populate the rooms
$roomList = $window.FindName("RoomList")
Get-Rooms | %{ $roomList.Items.Add($_) } | Out-Null
$roomList.SelectedIndex = 0

# wire up the Join Room button
$joinRoomButton = $window.FindName("JoinRoomButton")
$joinRoomButton.Add_Click({
    $selectedRoom = $roomList.SelectedItem
    Start-Process powershell -ArgumentList "$($pchatRoot)\LaunchRoom.ps1 '$selectedRoom'" -windowstyle hidden
}.GetNewClosure())

$window.ShowDialog()

