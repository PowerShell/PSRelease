$json = get-content "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9.3\Status\0.status" | ConvertFrom-Json
$json.status | Select-Object -Property Status, code | Format-Table -AutoSize
$substatus = $json.status.substatus[0].formattedMessage.message.replace('\n', "`n")
$substatus
