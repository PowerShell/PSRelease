# PowerShell Script to clone, build and package PowerShell from specified form and branch
# Script is intented to use in Docker containers
# Ensure PowerShell is available in the provided image

param (
	[string] $fork = "powershell",
	[string] $branch = "master",
	[string] $location = "/powershell",
    
    # Destination location of the package on docker host
    [string] $destination = '/mnt'
)

git clone --quiet https://github.com/$fork/powershell.git -b $branch
Push-Location
Set-Location "$location"
git submodule update --init --recursive --quiet
Import-Module "$location/build.psm1"
Start-PSBootstrap -Package -NoSudo
$output = Split-Path -Parent (Get-PSOutput -Options (New-PSOptions -Publish))
Start-PSBuild -Crossgen -PSModuleRestore

Start-PSPackage
Start-PSPackage -Type AppImage

Pop-Location

$linuxPackages = Get-ChildItem "$location/powershell*" -Include *.deb,*.rpm
$appImages = Get-ChildItem -Path "$location" -Filter "*.AppImage"
foreach($linuxPackage in $linuxPackages) 
{ 
    Copy-Item "$($linuxPackage.FullName)" "$destination" -force
}

foreach($appImage in $appImages) 
{ 
    Copy-Item "$($appImage.FullName)" "$destination" -force
}
