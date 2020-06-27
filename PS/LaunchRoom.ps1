#
# Intent is to keep this a standalone file so users can make shortcuts to launch a specific room.
# Alternatively, this can be spawned by a parent window that displays a user's accessible rooms

# .\LaunchRoom <room name>
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

$roomName = "Demo"
if ($args.Count -gt 0) {
    $roomName = $args[0]
}

# TODO: add validation check -- check room for existence and read/write access

# create initial files if they do not exist already
echo $null >> $historyFile
echo $null >> $debugLogFile

# State that gets shared among runspaces
$Hash = [hashtable]::Synchronized(@{})
$Hash.User = [System.Environment]::UserName
$Hash.PChatRoot = Get-PChatRoot
$Hash.RoomRoot = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($Hash.PChatRoot), "rooms", $roomName)
$Hash.ChatXamlFile = [System.IO.Path]::Combine($Hash.PChatRoot, "xaml", "ChatForm.xaml")
$Hash.ImagesRoot = [System.IO.Path]::Combine($Hash.RoomRoot, "images")
$Hash.HistoryFile = [System.IO.Path]::Combine($Hash.RoomRoot, "history.txt")
$Hash.RoomName = $roomName
$Hash.PendingMessages = [System.Collections.Concurrent.BlockingCollection[string]]::new([ConcurrentQueue[string]]::new())
$Hash.CancellationSource = New-Object System.Threading.CancellationTokenSource

Write-Host "Launching chat for room $roomName"
Write-Host "Settings: $Hash"

# create the runspace pool
[runspacefactory]::CreateRunspacePool()
$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$SessionState.Variables.Add((New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'Hash', $Hash, $null))
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, 5, $SessionState, $Host)
$RunspacePool.ApartmentState = 'STA'
$RunspacePool.Open()

# File Watcher runspace
$fsCmd = [PowerShell]::Create()
$fsCmd.AddScript({
    Get-Content $Hash.HistoryFile -Tail 1 -Wait | %{ $Hash.PendingMessages.Add($_.Trim()) }
})
$fsCmd.RunspacePool = $RunspacePool
$fsCmd.BeginInvoke()

$formCmd = [PowerShell]::Create()
$formCmd.AddScript({
    Function Add-ChatEvent($message) {
        echo $message >> $Hash.HistoryFile
    }

    function Get-ChatForm {
        $xaml = [xml](Get-Content -Path $Hash.ChatXamlFile)
        $reader = New-Object System.Xml.XmlNodeReader $xaml

        $window = [Windows.Markup.XamlReader]::Load($reader)
        $window.Title = "Room: $($Hash.RoomName)"

        $user = $Hash.User

        $sendMessageButton = $window.FindName("SendMessageButton")
    
        $sendMessageButton.Add_Click({
            $messageTextbox = $window.FindName("MessageTextbox")
            $text = $messageTextbox.Text

            Add-ChatEvent "[$($user)]: $text"

            $messageTextBox.Text = ""
        }.GetNewClosure())

        $sendScreenshotButton = $window.FindName("SendScreenshotButton")
        $sendScreenshotButton.Add_Click({
            $preImage = Get-Clipboard -Format Image
            SnippingTool.exe /clip | Out-Null
            $postImage = Get-Clipboard -Format Image

            if (($preImage -eq $null) -or (!$preImage.Size.Equals($postImage))) {
                $destFilename = "$(Get-Date -Format "yyyyMMdd-HHmmss")-$([System.Environment]::UserName).bmp"
                $destFile = [System.IO.Path]::Combine($Hash.ImagesRoot, $destFilename)

                $postImage.Save($destFile)

                Add-ChatEvent "$([System.Environment]::UserName) saved screenshot saved to $destFile"
                Add-ChatEvent "pchatimage:$destFile"
            }
        }.GetNewClosure())

        $messageTextbox = $window.FindName("MessageTextbox")
        $messageTextbox.Add_KeyDown({
            if ($_.Key -eq "Enter" -or $_.Key -eq "Return") {
                $sendMessageButton.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)));
            }
        }.GetNewClosure())

        $historyTextbox = $window.FindName("HistoryTextbox")
        $Hash.HistoryTextbox = $historyTextbox

        Add-ChatEvent "$user entered the chat"

        return $window
    }

    $form = Get-ChatForm
    $form.ShowDialog()
})

$formCmd.RunspacePool = $RunspacePool
$formCmdStatus = $formCmd.BeginInvoke()
        

# read from the pending history queue and marshal the appropriate UI manipulation onto the UI thread
$consumer = [PowerShell]::Create()
$consumer.AddScript({
    foreach ($pendingMessage in $Hash.PendingMessages.GetConsumingEnumerable($Hash.CancellationSource.Token)) {
        $str = $pendingMessage.Trim()
        if ($str.StartsWith("pchatimage:")) {
            $imagePath = $str.Substring(("pchatimage:").Length)
            $Hash.HistoryTextbox.Dispatcher.Invoke([action]{
                $bitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage -ArgumentList $imagePath
                $image = New-Object System.Windows.Controls.Image
                $image.Source = $bitmapImage

                # need this else it'll fill to the screen
                $image.Width = $bitmapImage.Width
                $image.Height = $bitmapImage.Height

                $container = New-Object System.Windows.Documents.InlineUIContainer -ArgumentList $image            
                $paragraph = New-Object System.Windows.Documents.Paragraph -ArgumentList $container
                $Hash.HistoryTextbox.Document.Blocks.Add($paragraph)
                $Hash.HistoryTextbox.AppendText("`r")
                $Hash.HistoryTextbox.ScrollToEnd()
            })
        } else {
            $Hash.HistoryTextbox.Dispatcher.Invoke([action]{ 
                $Hash.HistoryTextbox.AppendText("$($str)`r") 
                $Hash.HistoryTextbox.ScrollToEnd()
            })
        }
    }
})

$consumer.RunspacePool = $RunspacePool
$consumer.BeginInvoke()


while ($formCmdStatus.IsCompleted -ne $true) {}

# signal other runspaces to shutdown
$Hash.CancellationSource.Cancel()

$fsCmd.Dispose()
$consumer.Dispose()
$formCmd.Dispose()

$RunspacePool.Close()
$RunspacePool.Dispose()

Write-Host "done"