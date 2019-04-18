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

$agentZipUrl = 'https://vstsagentpackage.azureedge.net/agent/2.148.2/vsts-agent-win-x64-2.148.2.zip'
$installPsUrl = 'https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/install-powershell.ps1'

$pwshExe = Get-Command pwsh -ErrorAction Ignore

if (-not $pwshExe) {
    Invoke-WebRequest -Uri $installPsUrl -outFile ./install-powershell.ps1
    $pwshDestination = Join-Path -Path $env:SystemDrive -ChildPath "pwsh"
    ./install-powershell.ps1 -AddToPath -Destination $pwshDestination

    # A restart or logoff/logon is needed on older Windows OSes for updating the PATH environment variable
    Restart-Computer -Force
}

Invoke-WebRequest -Uri $agentZipUrl -outFile ./agent.zip

$agentPath = Join-Path -Path $env:SystemDrive -ChildPath 'AzDevOpsAgent'
[System.IO.Compression.ZipFile]::ExtractToDirectory("./agent.zip", $agentPath)

$workDir = Join-Path -Path $env:SystemDrive -ChildPath '1'
$null = New-Item -ItemType Directory -Path $workDir

Write-Host "Url: $Url"
Write-Host "Pool: $pool"
$configCmd = Join-Path -Path $agentPath -ChildPath 'config.cmd'
& $configCmd --unattended --url $Url --auth pat --token $Pat --pool $Pool --agent $env:Computername --work $workDir --runAsService
