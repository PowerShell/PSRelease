$username = 'builduser'
$password = 'Pa$$word'
$securePassword = $password|ConvertTo-SecureString -AsPlainText -Force
New-LocalUser -Name $username -Password $securePassword -AccountNeverExpires -PasswordNeverExpires -UserMayNotChangePassword
Add-LocalGroupMember -group administrators -Member $username
Enable-PSRemoting -Force -SkipNetworkProfileCheck -Verbose
Write-Verbose "Added $username as admin with password: $password" -Verbose
set-item wsman:/localhost/service/auth/basic $true
set-item wsman:/localhost/service/AllowUnencrypted $true
set-item wsman:/localhost/client/auth/basic $true
set-item wsman:/localhost/client/AllowUnencrypted $true
set-item WSMan:\localhost\Client\TrustedHosts -Value * -force
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\system /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f
Restart-Service winrm

$cred = [pscredential]::new($username,$securePassword)
$session = New-PSSession -ComputerName localhost -Credential $cred -Authentication Basic
if($session)
{
    Write-Verbose "got session" -Verbose
}
else {
    Write-Verbose "!!! did not get session!!!" -Verbose
}