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

Invoke-WebRequest -Uri $installPsUrl -outFile ./install-powershell.ps1

./install-powershell.ps1 -AddToPath

Invoke-WebRequest -Uri $agentZipUrl -outFile ./agent.zip

Expand-Archive -Path ./agent.zip -DestinationPath C:\AzDevOpsAgent -force

$workDir = 'C:\1'
$null = New-Item -ItemType Directory -Path $workDir

Write-Host "Url: $Url"
Write-Host "Pool: $pool"
C:\AzDevOpsAgent\config.cmd --unattended --url $Url --auth pat --token $Pat --pool $Pool --agent $env:Computername --work $workDir --runAsService
