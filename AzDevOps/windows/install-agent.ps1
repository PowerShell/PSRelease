# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
param(
    [parameter(Mandatory)]
    [string]$Url,
    [parameter(Mandatory)]
    [string]$Pat,
    [parameter(Mandatory)]
    [string]$Pool
)

$ErrorActionPreference = 'stop'

Write-Verbose -Verbose "PWD: $pwd"

$agentZipUrl = 'https://vstsagentpackage.azureedge.net/agent/2.148.2/vsts-agent-win-x64-2.148.2.zip'
$installPsUrl = 'https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/install-powershell.ps1'

$pwshExe = Get-Command pwsh -ErrorAction Ignore

if (-not $pwshExe) {
    Write-Verbose -Verbose "Installing pwsh"
    Invoke-WebRequest -Uri $installPsUrl -outFile ./install-powershell.ps1
    $pwshDestination = Join-Path -Path $env:SystemDrive -ChildPath "pwsh"
    ./install-powershell.ps1 -AddToPath -Destination $pwshDestination

    # set modify permission for Network Service, as AzDevOps agent runs in Network Service
    $acl = Get-Acl $pwshDestination
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("network service", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($accessRule)
    Set-Acl -Path $pwshDestination -AclObject $acl
}
else {
    Write-Verbose -Verbose "Skipping installing pwsh"
}

Write-Verbose -Verbose "Downlading agent.zip from $agentZipUrl"
Invoke-WebRequest -Uri $agentZipUrl -outFile ./agent.zip
Write-Verbose -Verbose "Completed downlading agent.zip"

# add user for vsts agent to runas
$randomObj = New-Object System.Random
$password = ""
1..(Get-Random -Minimum 15 -Maximum 126) | ForEach-Object { $password = $password + [char]$randomObj.next(45,126) }

$userName = 'VssAdministrator'
net user VssAdministrator $password /ADD

net localgroup administrators $userName /add
Write-Verbose -Verbose "User added to administrators group."

$agentPath = Join-Path -Path $env:SystemDrive -ChildPath 'AzDevOpsAgent'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory("./agent.zip", $agentPath)

$workDir = Join-Path -Path $env:SystemDrive -ChildPath '1'
$null = New-Item -ItemType Directory -Path $workDir

Write-Host "Url: $Url"
Write-Host "Pool: $pool"
$configCmd = Join-Path -Path $agentPath -ChildPath 'config.cmd'
& $configCmd --unattended --url $Url --auth pat --token $Pat --pool $Pool --agent $env:Computername --work $workDir --runAsAutoLogon --windowsLogonAccount $userName --windowsLogonPassword $password --noRestart
Write-Verbose -Verbose "Completed installing AzDevOps agent"

## Disable UAC and restart is needed
New-ItemProperty -Path HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system -Name EnableLUA -PropertyType DWord -Value 0 -Force

if (test-path $HOME\ps-rebooted.txt) {
    Write-Verbose -Verbose "We have already rebooted once."
 }
 else {
    Write-Verbose -Verbose "Rebooting"
    New-Item -ItemType File $HOME\ps-rebooted.txt > $null
    shutdown /r /t 30
 }
