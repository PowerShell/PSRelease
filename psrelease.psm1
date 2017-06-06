# VSTS task states: Succeeded|SucceededWithIssues|Failed|Cancelled|Skipped
$succeededStateName = 'Succeeded'
$warningStateName = 'SucceededWithIssues'
$errorStateName = 'Failed'

# store the current state used by *-VstsTaskState and Write-VstsMessage
$script:taskstate = $succeededStateName

# on pre-6.0 PowerShell $IsWindows doesn't exist, but those are always windows
if($IsWindows -eq $null)
{
    $IsWindows = $true
}

function Clear-VstsTaskState
{
    $script:taskstate = $succeededStateName
}

# Get the full images name based on the parameter
function Get-BuildImageName
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $image
    )

    return "microsoft/powershell:psrelease-$image"
}

# Get the destination for the build
if($IsWindows)
{
    $destination=$env:AGENT_WORKFOLDER
}
else {
    $destination=$env:BUILD_BINARIESDIRECTORY
}

function Get-Destination
{
    [cmdletbinding(DefaultParameterSetName='default')]
    param(
        [Parameter(ParameterSetName='full',Mandatory=$true)]
        [switch]$Full
    )

    if($env:BUILD_BINARIESDIRECTORY)
    {
        if($full.IsPresent)
        {
            return $env:BUILD_BINARIESDIRECTORY
        }
        # Docker cannot mount BUILD_BINARIESDIRECTORY
        return $destination
    }
    return $env:TEMP
}

function Get-TempFolder
{
    $tempPath = $env:TEMP
    if($env:AGENT_TEMPDIRECTORY)
    {
        $tempPath = $env:AGENT_TEMPDIRECTORY
    }

    $tempFolder = Join-Path -Path $tempPath -ChildPath ([System.IO.Path]::GetRandomFileName())
    if(!(test-path $tempFolder))
    {
        $null = New-Item -Path $tempFolder -ItemType Directory
    }

    return $tempFolder
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

        # for linux images, use the common folder for the context
        if($image -ne 'windowsservercore')
        {
            $contextPath = Get-TempFolder
            $genericFilesPath = Join-Path (Join-Path (join-path $PSScriptRoot -ChildPath 'Images')  -ChildPath "GenericLinuxFiles") -ChildPath '*'
            Copy-Item -Path $genericFilesPath -Destination $contextPath
            Copy-Item -Path $dockerFilePath -Destination $contextPath
        }
        else 
        {
            $contextPath = $imagePath
        }

        # always log docker host information to allow troubleshooting issues with docker
        Write-Verbose "Docker_host: $env:DOCKER_HOST" -Verbose
        $null = Invoke-Docker -command build -params '--force-rm', '--tag', $imageName, $contextPath
        $null = Invoke-Docker -command images -params 'ls' -FailureAction warning

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

        $dockerContainerName = 'pswscbuild'

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
            $null = Invoke-Docker -command 'container', 'cp' -params "${dockerContainerName}:$outputFolder", $env:BUILD_BINARIESDIRECTORY
            Remove-Container 
        }
    } 
    catch
    {
        Write-VstsError $_
    }
}

# Call Docker with appropriate result checks
function Invoke-Docker 
{
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $Command,
        [ValidateSet("error","warning",'ignore')]
        $FailureAction = 'error',
        [Parameter(Mandatory=$true)]
        [string[]]
        $Params,
        [switch]
        $PassThru,
        [switch]
        $SupressHostOutput
    )

    $ErrorActionPreference = 'Continue'

    # Log how we are running docker for troubleshooting issues
    Write-Verbose "Running docker $command $params" -Verbose
    if($SupressHostOutput.IsPresent)
    {
        $result = &'docker' $command $params 2>&1
    }
    else 
    {
        &'docker' $command $params 2>&1 | Tee-Object -Variable result -ErrorAction SilentlyContinue | Out-String -Stream -ErrorAction SilentlyContinue | Write-Host -ErrorAction SilentlyContinue
    }

    $dockerExitCode = $LASTEXITCODE
    if($PassThru.IsPresent)
    {
        return $result
    }
    elseif($dockerExitCode -ne 0 -and $FailureAction -eq 'error')
    {
        Write-VstsMessage -type error -message "docker $command failed with: $result"
        return $false
    }
    elseif($dockerExitCode -ne 0 -and $FailureAction -eq 'warning')
    {
        Write-VstsMessage -type warning -message "docker $command failed with: $result"
        return $false
    }
    elseif($dockerExitCode -ne 0)
    {
        return $false
    }
    
    return $true
}

function Remove-Container
{
    param(
        [ValidateSet('warning','ignore')]
        $FailureAction = 'warning'
    )

    $commonDockerParams = @{
        FailureAction = $FailureAction
        SupressHostOutput = $true
    }

    # stop all running containers
    Invoke-Docker -Command 'ps' -Params '--format', '{{ json .}}' @commonDockerParams -PassThru | 
        Where-Object {$_ -ne $null} |
        ConvertFrom-Json | 
        Where-Object { $null = Invoke-Docker -Command stop -Params $_.Names  @commonDockerParams} 

    # remove all containers
    Invoke-Docker -Command 'ps' -Params '--format', '{{ json .}}', '--all' @commonDockerParams -PassThru | 
        Where-Object {$_ -ne $null} |
        ConvertFrom-Json | 
        Where-Object { $null = Invoke-Docker -Command rm -Params $_.Names  @commonDockerParams} 
} 

# Publishes build artifacts 
function Invoke-PSPublishBuildArtifact
{
    $ErrorActionPreference = 'Continue'
    if($env:BUILD_BINARIESDIRECTORY)
    {
        $filter = Join-Path -Path (Get-Destination -Full) -ChildPath '*'

        # In VSTS, publish artifacts appropriately
        $files = Get-ChildItem -Path $filter -Recurse | Select-Object -ExpandProperty FullName

        foreach($fileName in $files)
        {
            $leafFileName = $(Split-path -Path $FileName -Leaf)

            $extension = [System.io.path]::GetExtension($fileName)
            if($extension -ieq '.zip')
            {
                Expand-Archive -Path $fileName -DestinationPath (Join-Path $env:Build_StagingDirectory -ChildPath $leafFileName)
            }

            Write-Host "##vso[artifact.upload containerfolder=results;artifactname=$leafFileName]$FileName"
        }
    }
}

function Write-VstsError {
    param(
        [Parameter(Mandatory=$true)]
        [Object]
        $Error
    )

    $message = [string]::Empty
    $errorType = $Error.GetType().FullName
    $newLine = [System.Environment]::NewLine
    switch($errorType)
    {
        'System.Management.Automation.ErrorRecord'{
            $message = "{0}{2}`t{1}" -f $Error,$Error.ScriptStackTrace,$newLine
        }
        'System.Management.Automation.ParseException'{
            $message = "{0}{2}`t{1}" -f $Error,$Error.StackTrace,$newLine
        }
        'System.Management.Automation.Runspaces.RemotingErrorRecord'
        {
            $message = "{0}{2}`t{1}{2}`tOrigin: {2}" -f $Error,$Error.ScriptStackTrace,$Error.OriginInfo,$newLine
        }
        default
        {
            # Log any unknown error types we get so  we can improve logging.
            Write-Verbose "errorType: $errorType" -Verbose
            $message =  $Error.ToString()
        }
    }
    $message.Split($newLine) | ForEach-Object {
        Write-VstsMessage -type error -message $PSItem
    }
}


function Write-VstsMessage {
    param(
        [ValidateSet("error","warning")]
        $type = 'error',
        [String]
        $message
    )

    if($script:taskstate -ne $errorStateName -and $type -eq 'error')
    {
        $script:taskstate = $errorStateName
    }
    elseif($script:taskstate -eq $succeededStateName) {
        $script:taskstate = $warningStateName
    }

    # See VSTS documentation at https://github.com/Microsoft/vsts-tasks/blob/master/docs/authoring/commands.md
    # Log task message
    Write-Host "##vso[task.logissue type=$type]$message"
}

function Write-VstsTaskState
{
    # See VSTS documentation at https://github.com/Microsoft/vsts-tasks/blob/master/docs/authoring/commands.md
    # Log task state
    Write-Host "##vso[task.complete result=$script:taskstate;]DONE"
}

Export-ModuleMember @(
    'Invoke-PSBuildContainer'
    'Invoke-PSDockerBuild'
    'Invoke-PSPublishBuildArtifact'
    'Write-VstsError'
    'Clear-VstsTaskState'
    'Write-VstsTaskState'
)