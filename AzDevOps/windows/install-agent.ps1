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

$agentPath = Join-Path -Path $env:SystemDrive -ChildPath 'AzDevOpsAgent'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory("./agent.zip", $agentPath)

$workDir = Join-Path -Path $env:SystemDrive -ChildPath '1'
$null = New-Item -ItemType Directory -Path $workDir

Write-Host "Url: $Url"
Write-Host "Pool: $pool"
$configCmd = Join-Path -Path $agentPath -ChildPath 'config.cmd'
& $configCmd --unattended --url $Url --auth pat --token $Pat --pool $Pool --agent $env:Computername --work $workDir --runAsService
Write-Verbose -Verbose "Completed installing AzDevOps agent"

if (-not $pwshExe) {
    # A restart or logoff/logon is needed on older Windows OSes for updating the PATH environment variable
    # Cannot use Restart-Computer as it will set the exit code to 1 with -Force
    # /t greater than 0 implies force.
    Write-Verbose -Verbose "Rebooting"
    shutdown /r /t 30
}
