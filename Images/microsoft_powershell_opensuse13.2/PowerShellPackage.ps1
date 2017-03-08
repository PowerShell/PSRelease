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

git clone --recursive https://github.com/$fork/powershell.git -b $branch 2> $null
Push-Location
Set-Location "$location"
Import-Module "$location/build.psm1"
Start-PSBootstrap -Package -NoSudo
$output = Split-Path -Parent (Get-PSOutput -Options (New-PSOptions -Publish))

#TODO update to use crossgen
Start-PSBuild -Runtime 'opensuse.13.2-x64' -PSModuleRestore -Publish

#TODO update with Start-PSPackage once we crossGen
$Version = (git --git-dir="$PWD/.git" describe) -Replace '^v'
New-UnixPackage -Type rpm -PackageSourcePath $output -Name powershell -Version $Version
Pop-Location

$linuxPackages = Get-ChildItem "$location/powershell*" -Include *.deb,*.rpm,*.AppImage
foreach($linuxPackage in $linuxPackages) 
{ 
    Copy-Item "$($linuxPackage.FullName)" "$destination" -force
}
