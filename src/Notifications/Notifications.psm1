Function Send-Notification ($Title, $Content) {

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

$app = '7d9b4369-2581-44ee-a47b-3eb7407ebcab'

$template = @"
<toast>
    <visual>
        <binding template="ToastText02" >
            <text id="1">$Title</text>
            <text id="2">$Content</text>
        </binding>
    </visual>
    <actions>
        <action activationType="background" content="Ack" arguments="later"/>
    </actions>
    <audio silent="true"/>
</toast>
"@

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($template)
$toast = New-Object Windows.UI.Notifications.ToastNotification $xml
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app).Show($toast)

}

Export-ModuleMember -Function Send-Notification