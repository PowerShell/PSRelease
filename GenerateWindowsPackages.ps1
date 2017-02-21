# PowerShell Script to clone, build and package PowerShell from specified fork and branch
param (
	[string] $fork = 'powershell',
	[string] $branch = 'master',
	[string] $location = "$pwd\powershell",
	[string] $destinationPath = "$env:WORKSPACE",
        [ValidateSet("win7-x64", "win81-x64", "win10-x64", "win7-x86")]    
        [string]$Runtime = 'win10-x64'
)

Remove-Item $location -Recurse -Force -ErrorAction SilentlyContinue

$gitBinFullPath = (Join-Path "$env:ProgramFiles" 'git\bin\git.exe')
Write-Verbose "Ensure Git for Windows is available @ $gitBinFullPath"
if (-not (Test-Path $gitBinFullPath))
{
    throw "Git for Windows is required to proceed. Install from 'https://git-scm.com/download/win'"
}

& $gitBinFullPath clone -b $branch --recursive https://github.com/$fork/powershell.git $location

Push-Location
Set-Location $location

[Environment]::SetEnvironmentVariable("HOMEDRIVE", 'c:\')
[Environment]::SetEnvironmentVariable("HOMEPATH", '\Users\Jenkins-Admin')
[Environment]::SetEnvironmentVariable("HOME", 'c:\Users\Jenkins-Admin')

Import-Module "$location\build.psm1" -Force

Start-PSBootstrap -Package -Force

Start-PSBuild -Clean -CrossGen -Publish -PSModuleRestore -Runtime $Runtime -Configuration Release

$pspackageParams = @{'Type'='msi'}
if ($Runtime -ne 'win10-x64')
{
    $pspackageParams += @{'WindowsDownLevel'=$Runtime}
}

Start-PSPackage @pspackageParams

$pspackageParams['Type']='zip'
Start-PSPackage @pspackageParams

Copy $location\*.msi $destinationPath -ErrorAction SilentlyContinue -Force
Copy $location\*.zip $destinationPath -ErrorAction SilentlyContinue -Force

Pop-Location
