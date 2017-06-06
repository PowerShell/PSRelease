# PowerShell Script to clone, build and package PowerShell from specified form and branch
# Script is intented to use in Docker containers
# Ensure PowerShell is available in the provided image

param (
    [string] $fork = "powershell",
    [string] $branch = "master",
    [string] $location = "/powershell",

    # Destination location of the package on docker host
    [string] $destination = '/mnt',

    [ValidatePattern("^v\d+\.\d+\.\d+(-\w+\.\d+)?$")]
    [ValidateNotNullOrEmpty()]
    [string]$ReleaseTag,
    [switch]$AppImage
)

$releaseTagParam = @{}
if($ReleaseTag)
{
    $releaseTagParam = @{ 'ReleaseTag' = $ReleaseTag }
}

git clone --quiet https://github.com/$fork/powershell.git -b $branch $location
Push-Location
try {
    Set-Location $location
    git submodule update --init --recursive --quiet
    Import-Module "$location/build.psm1"
    Start-PSBootstrap -Package -NoSudo
    Start-PSBuild -Crossgen -PSModuleRestore @releaseTagParam

    Start-PSPackage @releaseTagParam
    if($AppImage.IsPresent)
    {
        Start-PSPackage -Type AppImage @releaseTagParam
    }
}
finally
{
    Pop-Location
}

$linuxPackages = Get-ChildItem "$location/powershell*" -Include *.deb,*.rpm
    
foreach($linuxPackage in $linuxPackages) 
{ 
    Copy-Item $linuxPackage.FullName $destination -force
}

if($AppImage.IsPresent)
{
    $appImages = Get-ChildItem -Path $location -Filter '*.AppImage'
    foreach($appImage in $appImages) 
    { 
        Copy-Item $appImage.FullName $destination -force
    }
}
