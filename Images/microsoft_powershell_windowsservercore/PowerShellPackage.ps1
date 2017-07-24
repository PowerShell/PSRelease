[cmdletbinding()]
# PowerShell Script to clone, build and package PowerShell from specified fork and branch
param (
    [string] $fork = 'powershell',
    [string] $branch = 'master',
    [string] $location = "$pwd\powershell",
    [string] $destination = "$env:WORKSPACE",
    [ValidateSet("win7-x64", "win81-x64", "win10-x64", "win7-x86")]    
    [string]$Runtime = 'win10-x64',
    [switch] $Wait,
    [ValidatePattern("^v\d+\.\d+\.\d+(-\w+\.\d+)?$")]
    [ValidateNotNullOrEmpty()]
    [string]$ReleaseTag
)

$releaseTagParam = @{}
if($ReleaseTag)
{
    $releaseTagParam = @{ 'ReleaseTag' = $ReleaseTag }
}

if(-not $env:homedrive)
{
    Write-Verbose "fixng empty home paths..." -Verbose
    $profileParts = $env:userprofile -split ':'
    $env:homedrive = $profileParts[0]+':'
    $env:homepath = $profileParts[1]
}

if(! (Test-Path $destination))
{
    Write-Verbose "Creating destination $destination" -Verbose
    $null = New-Item -Path $destination -ItemType Directory -Force
}

Write-Verbose "homedrive : ${env:homedrive}"
Write-Verbose "homepath : ${env:homepath}"
Write-Verbose "Cleaning build location..." -Verbose
Remove-Item $location -Recurse -Force -ErrorAction SilentlyContinue

# Don't use CIM_PhysicalMemory, docker containers may cache old values
$memoryMB = (Get-CimInstance win32_computersystem).TotalPhysicalMemory /1MB
$requiredMemoryMB = 2048
if($memoryMB -lt $requiredMemoryMB)
{
    throw "Building powershell requires at least $requiredMemoryMB MiB of memory and only $memoryMB MiB is present."
}
Write-Verbose "Running with $memoryMB MB memory." -Verbose

$gitBinFullPath = (Join-Path "$env:ProgramFiles" 'git\bin\git.exe')
Write-Verbose "Ensure Git for Windows is available @ $gitBinFullPath" -Verbose
if (-not (Test-Path $gitBinFullPath))
{
    throw "Git for Windows is required to proceed. Install from 'https://git-scm.com/download/win'"
}

Write-Verbose "cloning -b $branch https://github.com/$fork/powershell.git" -verbose
& $gitBinFullPath clone -b $branch --quiet https://github.com/$fork/powershell.git $location

try{
    Set-Location $location
    & $gitBinFullPath  submodule update --init --recursive --quiet

    Import-Module "$location\build.psm1" -Force
    Import-Module "$location\tools\packaging" -Force
    $env:platform = $null
    Write-Verbose "Bootstrapping powershell build..." -verbose
    Start-PSBootstrap -Force -Package

    Write-Verbose "Starting powershell build for RID: $Runtime and ReleaseTag: $ReleaseTag ..." -verbose
    Start-PSBuild -Clean -CrossGen -PSModuleRestore -Runtime $Runtime -Configuration Release @releaseTagParam

    $pspackageParams = @{'Type'='msi'}
    if ($Runtime -ne 'win10-x64')
    {
        $pspackageParams += @{'WindowsDownLevel'=$Runtime}
    }

    Write-Verbose "Starting powershell packaging(msi)..." -verbose
    Start-PSPackage @pspackageParams @releaseTagParam

    $pspackageParams['Type']='zip'
    Write-Verbose "Starting powershell packaging(zip)..." -verbose
    Start-PSPackage @pspackageParams @releaseTagParam

    Write-Verbose "Exporting packages ..." -verbose
    $files= @()

    Get-ChildItem $location\*.msi |Select-Object -ExpandProperty FullName | ForEach-Object {
        $files += $_
    }

    Get-ChildItem $location\*.zip |Select-Object -ExpandProperty FullName | ForEach-Object {
        $files += $_
    }

    Foreach($file in $files)
    {
        Write-Verbose "Copying $file to $destination" -verbose
        Copy-Item -Path $file -Destination "$destination\" -Force
    }
}
finally
{
    Write-Verbose "Beginning build clean-up..." -verbose
    if($Wait.IsPresent)
    {
        $path = Join-Path $PSScriptRoot -ChildPath 'delete-to-continue.txt'
        $null = New-Item -Path $path -ItemType File
        Write-Verbose "Computer name: $env:COMPUTERNAME" -Verbose
        Write-Verbose "Delete $path to exit." -Verbose
        while(Test-Path -LiteralPath $path)
        {
            Start-Sleep -Seconds 60
        }
    }
}
