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

# TODO: add validation checks
# 1) check read/write access if the room exists
# 2) handle errors creating a new room if the user does not have write access to do so

# Create the initial directories and files.  if they already exist, these are no-ops
$pchatRoot = Get-PChatRoot
$roomRoot = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($pchatRoot), "rooms", $roomName)
$imagesRoot = [System.IO.Path]::Combine($roomRoot, "images")

New-Item -ItemType Directory -Force -Path $roomRoot
New-Item -ItemType Directory -Force -Path $imagesRoot
Write-Output $null >> $historyFile
Write-Output $null >> $debugLogFile

# State that gets shared among runspaces
$Hash = [hashtable]::Synchronized(@{})
$Hash.User = [System.Environment]::UserName
$Hash.PChatRoot = $pchatRoot
$Hash.RoomRoot = $roomRoot
$Hash.ChatXamlFile = [System.IO.Path]::Combine($Hash.PChatRoot, "xaml", "ChatForm.xaml")
$Hash.ImagesRoot = $imagesRoot
$Hash.HistoryFile = [System.IO.Path]::Combine($Hash.RoomRoot, "history.txt")
$Hash.RoomName = $roomName
$Hash.PendingMessages = [System.Collections.Concurrent.BlockingCollection[string]]::new([ConcurrentQueue[string]]::new())
$Hash.CancellationSource = New-Object System.Threading.CancellationTokenSource
$Hash.IgnoreFileChanges = $false
$Hash.DebugFile = [System.IO.Path]::Combine($Hash.RoomRoot, "debug.txt")

Write-Host "Launching chat for room $roomName"

# create the runspace pool
[runspacefactory]::CreateRunspacePool()
$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$SessionState.Variables.Add((New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'Hash', $Hash, $null))
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, 5, $SessionState, $Host)
$RunspacePool.ApartmentState = 'STA'
$RunspacePool.Open()

$formCmd = [PowerShell]::Create()
$formCmd.AddScript({
    function Add-ChatEvent($message) {
        Write-Output "$message" >> $Hash.HistoryFile
    }

    function Get-ChatForm {
        $xaml = [xml](Get-Content -Path $Hash.ChatXamlFile)
        $reader = New-Object System.Xml.XmlNodeReader $xaml

        $window = [Windows.Markup.XamlReader]::Load($reader)

        # add icon
        $window.Icon = [System.IO.Path]::Combine($pchatRoot , "src" , "resources", "pChatIcon.ico")
        Write-Host "Value " [System.IO.Path]::Combine($pchatRoot , "src" , "resources", "pChatIcon.ico")
        $window.Title = "Room: $($Hash.RoomName)"

        $user = $Hash.User

        $chatLocationLabel = $window.FindName("ChatLocationLabel")
        $chatLocationLabel.Content += $Hash.RoomRoot

        $sendMessageButton = $window.FindName("SendMessageButton")
    
        $sendMessageButton.Add_Click({
            $messageTextbox = $window.FindName("MessageTextbox")
            $text = $messageTextbox.Text

            Add-ChatEvent "[$($user)]: $text"

            $messageTextBox.Text = ""
        }.GetNewClosure())

        $sendScreenshotButton = $window.FindName("SendScreenshotButton")
        $sendScreenshotButton.Add_Click({
            # could not find a way to determine if the user it escape (to cancel) the screenshot or not.
            # so, do a poor man's diff of the before and after images to determine whether to proceed
            $preImage = Get-Clipboard -Format Image
            SnippingTool.exe /clip | Out-Null
            $postImage = Get-Clipboard -Format Image

            if (($null -eq $preImage) -or (!$preImage.Size.Equals($postImage.Size))) {
                $destFilename = "$(Get-Date -Format "yyyyMMdd-HHmmss")-$([System.Environment]::UserName).bmp"
                $destFile = [System.IO.Path]::Combine($Hash.ImagesRoot, $destFilename)

                $postImage.Save($destFile)

                Add-ChatEvent "$([System.Environment]::UserName) sent screenshot [$destFile]"
                Add-ChatEvent "pchatimage:$destFile"
            }
        }.GetNewClosure())

        $messageTextbox = $window.FindName("MessageTextbox")
        $messageTextbox.Add_KeyDown({
            if ($_.Key -eq "Enter" -or $_.Key -eq "Return") {
                $sendMessageButton.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)));
            }
        }.GetNewClosure())

         # add a single paragraph that we can keep appending text and screenshots to
        $historyTextbox = $window.FindName("HistoryTextbox")
        $Hash.HistoryTextbox = $historyTextbox
        $Hash.HistoryParagraph = New-Object System.Windows.Documents.Paragraph
        $historyTextbox.Document.Blocks.Add($Hash.HistoryParagraph)

        Add-ChatEvent "$user entered the chat"

        return $window
    }

    $form = Get-ChatForm
    $form.ShowDialog()

    $Hash.IgnoreFileChanges = $true
    Add-ChatEvent "$($Hash.User) left the chat"
})

$formCmd.RunspacePool = $RunspacePool
$formCmdStatus = $formCmd.BeginInvoke()

# File Watcher runspace
$fsCmd = [PowerShell]::Create()
$fsCmd.AddScript({
    # in certain cases (such as a fresh room), we can't immediately watch this file for changes.
    # add a loop here in case Get-Content exits prematurely
    while (!$Hash.CancellationSource.IsCancellationRequested) {
        Get-Content $Hash.HistoryFile -Tail 50 -Wait | ForEach-Object { 
            if (!$Hash.IgnoreFileChanges) {
                $Hash.PendingMessages.Add($_.Trim()) 
            }
        }
    }
})
$fsCmd.RunspacePool = $RunspacePool
$fsCmd.BeginInvoke()

# read from the pending history queue and marshal to the UI thread and stylize as appropriate
$consumer = [PowerShell]::Create()
$consumer.AddScript({
    #import notification module
    Import-Module "$($Hash.PChatRoot)\Notifications"

    function Add-MessagesToRichTextBox($rawMessages, $sendNotification) {
        # jump into the UI thread at this point and do this as a batch
        $Hash.HistoryTextbox.Dispatcher.Invoke([action]{
            # aggregate the changes all at once to avoid flicker in the textbox
            $changes = @()
            foreach ($rawMessage in $rawMessages) {
                if ($sendNotification -and !($rawMessage.StartsWith("[$($Hash.User)]") -or $rawMessage.StartsWith($Hash.User) -or $rawMessage.StartsWith("pchatimage"))) {
                    Send-Notification -Title "PChat Notificaton" -Content "$rawMessage"
                }

                $changes += Get-FlowDocumentChanges($rawMessage)
            }

            foreach ($change in $changes) {
                if ($change["type"] -eq "inline-addition") {
                    foreach ($run in $change["runs"]) {
                        $Hash.HistoryParagraph.Inlines.Add($run)
                    }
                } elseif ($change["type"] -eq "child-addition") {
                    $Hash.HistoryParagraph.AddChild($change["child"])
                }
            }

           $Hash.HistoryTextbox.ScrollToEnd()
        }.GetNewClosure())
    }

    function Get-FlowDocumentChanges($rawMessage) {
        $changes = @()

        # we have 2 interesting classes of 'rawMessage'.
        # each has different changes to the flow document
        
        # (1) [alias]: blah blah may have a hyperlink
        # (2) pchatimage:\\file\path\here.bmp
        # (3) alias entered/left the room
        
        # case (1)
        if ($rawMessage.StartsWith("[")) {
            $change = @{"type"="inline-addition"; "runs"=@()}

            # build the changes to colorize the [alias] portion

            $username = $rawMessage.Substring(0, $rawMessage.IndexOf(":"))
            $content = $rawMessage.Substring($rawMessage.IndexOf(":"))

            $nameRun = New-Object System.Windows.Documents.Run($username)
            $nameRun.Foreground = [System.Windows.Media.Brushes]::Blue

            $change["runs"] += $nameRun

            # replace any https:// addresses with a clickable hyperlink
            $parts = $content.Split(' ')
            foreach ($part in $parts) {
                if ($part.StartsWith("https://")) {
                    $link = New-Object System.Windows.Documents.Hyperlink
                    $link.IsEnabled = $true
                    $link.Inlines.Add("$part")
                    $link.NavigateUri = New-Object System.Uri -ArgumentList $part
                    $link.Add_RequestNavigate({ Start-Process $part }.GetNewClosure())

                    $change["runs"] += $link

                    $spaceRun = New-Object System.Windows.Documents.Run(" ")
                    $change["runs"] += $spaceRun
                }
                else {
                    $partRun = New-Object System.Windows.Documents.Run("$part ")
                    $change["runs"] += $partRun
                }
            }

            # append a newline
            $newlineRun = New-Object System.Windows.Documents.Run("`r")
            $change["runs"] += $newlineRun

            $changes += $change
        # case (2)
        } elseif ($rawMessage.StartsWith("pchatimage:")) {
            $imagePath = $rawMessage.Substring(("pchatimage:").Length)

            # pchat image handling
            $bitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage -ArgumentList $imagePath
            $image = New-Object System.Windows.Controls.Image
            $image.Source = $bitmapImage

            # need this else it'll fill to the screen
            $image.Width = $bitmapImage.Width
            $image.Height = $bitmapImage.Height

            $container = New-Object System.Windows.Documents.InlineUIContainer -ArgumentList $image       
            
            $change1 = @{"type"="child-addition"; "child"=$container}
            $changes += $change1

            # append a newline
            $newlineRun = New-Object System.Windows.Documents.Run("`r")
            $change2 = @{"type"="inline-addition"; "runs"=@( $newlineRun )}
            
            $changes += $change2
        # case (3)
        } else {
            $run = New-Object System.Windows.Documents.Run("$($rawMessage)`r")
            $change = @{"type"="inline-addition"; "runs"=@($run)}

            $changes += $change
        }
            
        return $changes
    }

    # race condition here.  we may end up processing new messages before the History Textbox is fully setup.
    # add a loop here to wait until the history textbox is setup before processing pending messages
    while ((($Hash.HistoryTextbox.Document.Blocks.Count) -eq 0) -and (!$Hash.CancellationSource.IsCancellationRequested)) {
        Start-Sleep -Milliseconds 250
    }

    # treat initial messages separately, as they are likely historical
    # we do not want to show toast notification for them
    $oldMessages = @()
    $oldMessage = ''
    while ($Hash.PendingMessages.TryTake([ref]$oldMessage)) {
        $oldMessages += $oldMessage
    }
    Add-MessagesToRichTextBox $oldMessages $false

    # all caught-up with old message.  hit the new ones
    foreach ($pendingMessage in $Hash.PendingMessages.GetConsumingEnumerable($Hash.CancellationSource.Token)) {
        $str = $pendingMessage.Trim()
        Add-MessagesToRichTextBox @($str) $true
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