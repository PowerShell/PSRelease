Import-Module "$PSScriptRoot/vstsBuild" -Scope Global
Import-Module "$PSScriptRoot/dockerBasedBuild"
Import-Module "$PSScriptRoot/dockerBasedBuild/dockerBasedBuild.common.psm1"

# on pre-6.0 PowerShell $IsWindows doesn't exist, but those are always windows
if($IsWindows -eq $null)
{
    $IsWindows = $true
}

# Builds a Docker container for an image
function Invoke-PSBuildContainer
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('centos7','opensuse42.1','ubuntu14.04','ubuntu16.04','windowsservercore')]
        [string]
        $image
    )

    $ErrorActionPreference = 'Stop'

    try {
        $imagePath = Join-Path (join-path $PSScriptRoot -ChildPath 'Images')  -ChildPath "microsoft_powershell_$image"
        $dockerFilePath = Join-Path -Path $imagePath -ChildPath Dockerfile
        
        $imageName = Get-BuildImageName -image $image
        $buildParameters = @{
            DockerFilePath = $dockerFilePath
            ImageName = $imageName
        }

        # for linux images, use the common folder for the context
        if($image -ne 'windowsservercore')
        {
            $contextPath = Get-TempFolder
            $buildParameters['AdditionalContextFiles']=@('./Images/GenericLinuxFiles/PowerShellPackage.ps1')
            $buildParameters['ContextPath']=$contextPath
        }

        Invoke-BuildContainer @buildParameters

        if($image -ne 'windowsservercore')
        {
            remove-item $contextPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    } 
    catch
    {
        Write-VstsError $_
    }
}


# Builds PowerShell in a Docker container
function Invoke-PSDockerBuild
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('centos7','opensuse42.1','ubuntu14.04','ubuntu16.04','windowsservercore')]
        [string]
        $image,

        [ValidateNotNullOrEmpty()]
        [string] $fork = 'powershell',

        [ValidateNotNullOrEmpty()]
        [string] $branch = 'master',

        [ValidateNotNullOrEmpty()]
        [string] $location,

        [ValidateNotNullOrEmpty()]
        [string] $destination = (Get-Destination),

        [Parameter(Mandatory=$true)]
        [ValidateSet("win7-x64", "win81-x64", "win10-x64", "win7-x86","ubuntu.16.04-x64","ubuntu.14.04-x64","centos.7-x64","opensuse.42.1-x64")]    
        [string]$Runtime,

        [switch]$AppImage,

        [ValidatePattern("^v\d+\.\d+\.\d+(-\w+\.\d+)?$")]
        [ValidateNotNullOrEmpty()]
        [string]$ReleaseTag
    )

    $ErrorActionPreference = 'Stop'

    try {
        $imageName = Get-BuildImageName -image $image
        if($image -eq 'windowsservercore')
        {
            $outputFolder = 'C:\out'
            if(!$location)
            {
                $location = "C:\powershell"
            }
        }
        else 
        {
            if(!$location)
            {
                $location = "/powershell"
            }
            $outputFolder = '/mnt'
        }
        
        if(!(Test-Path $destination))
        {
            $null = New-Item -Path $destination -ItemType Directory -Force
        }

        $dockerContainerName = 'pswscbuildlegacy'

        $volumeMapping = "${destination}:$outputFolder"
        $params = @('-i')
        if($image -eq 'windowsservercore')
        {
            $params += '-m'
            $params += '3968m'
            $params += '--name'
            $params += $dockerContainerName
        }
        else 
        {
            $params += '--rm'
            $params += '-v'
            $params += $volumeMapping
        }

        if($AppImage.IsPresent)
        {
            $params += '--cap-add'
            $params += 'SYS_ADMIN'
            $params += '--cap-add'
            $params += 'MKNOD'
            $params += '--device=/dev/fuse'
            $params += '--security-opt'
            $params += 'apparmor:unconfined'
        }

        $params += $imageName
        $params += '.\PowerShellPackage.ps1'
        $params += '-branch'
        $params += $branch
        $params += '-location'
        $params += $location
        $params += '-destination'
        $params += $outputFolder
        if($AppImage.IsPresent)
        {
            $params += '-AppImage'
        }

        if($ReleaseTag)
        {
            $params += '-ReleaseTag'
            $params += $ReleaseTag
        }

        if($image -eq 'windowsservercore')
        {
            $params += '-Runtime'
            $params += $Runtime
        }

        if($IsWindows)
        {
            Remove-Container -FailureAction ignore
        }

        $null = Invoke-Docker -command run -params $params

        if($IsWindows)
        {
            $null = Invoke-Docker -command 'container', 'cp' -params "${dockerContainerName}:$outputFolder", $destination
            Remove-Container 
        }

        Invoke-VstsPublishBuildArtifact
    } 
    catch
    {
        Write-VstsError $_
    }
}

Export-ModuleMember @(
    'Invoke-PSBuildContainer'
    'Invoke-PSDockerBuild'
    'Invoke-PSPublishBuildArtifact'
)
