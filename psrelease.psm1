
Import-Module "$PSScriptRoot\vstsBuild"
Import-Module "$PSScriptRoot\dockerBaseBuild"
Import-Module "$PSScriptRoot\dockerBasedBuild\dockerBasedBuild.common.psm1"
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
            $buildParameters['AdditionalContextFiles']=@(genericFilesPath)
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

# Builds a Docker container for an image
function Invoke-BuildContainer
{
    [cmdletbinding(DefaultParameterSetName='default')]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $DockerFilePath,

        [Parameter(Mandatory=$true)]
        [string]
        $ImageName,

        [string[]]
        $AdditionalContextFiles,

        [string]
        $ContextPath,

        [Parameter(ParameterSetName='addrepo',Mandatory)]
        [switch]
        $AddRepo,

        [Parameter(ParameterSetName='addrepo',Mandatory)]
        [string]
        $RepoLocation,

        [Parameter(ParameterSetName='addrepo',Mandatory)]
        [string]
        $ContainerRepoLocation
    )

    $ErrorActionPreference = 'Stop'

    try {
        $runtimeContextPath = $null
        if($ContextPath)
        {
            $runtimeContextPath = $ContextPath
            Copy-Item -Path $dockerFilePath -Destination $contextPath
            foreach($additionalContextFile in $AdditionalContextFiles)
            {
                Copy-Item -Path $additionalContextFile -Destination $contextPath 
            }
        }
        else 
        {
            $runtimeContextPath = Split-Path -Path $DockerFilePath    
        }

        $dockerBuildImageName = $ImageName
        if($AddRepo)
        {
            $dockerBuildImageName = $ImageName+'-without-repo'
        }

        # always log docker host information to allow troubleshooting issues with docker
        log "Docker_host: $env:DOCKER_HOST"
        # Build the container, pulling to ensure we have the newest base image
        $null = Invoke-Docker -command build -params '--pull', '--tag', $dockerBuildImageName, $runtimeContextPath

        if($contextPath)
        {
            remove-item $contextPath -Recurse -Force -ErrorAction SilentlyContinue
        }

        if($AddRepo.IsPresent)
        {
            $dockerContainerName = 'pswsctemp'

            $repoFolderName = 'repolink'

            $dockerBuildFolder = Get-TempFolder

            $repoPath = Join-Path -Path $dockerBuildFolder -ChildPath $repoFolderName

            try 
            {
                $addRepoDockerFilePath = Join-Path -Path $dockerBuildFolder -ChildPath 'Dockerfile'
                
                # TODO: redo using symbolic links, but hit many isssue using them.
                log "Copying repo from: $RepoLocation to: $RepoPath"
                Copy-item -path $RepoLocation -Destination $RepoPath -Recurse
                
                $psreleaseStrings.dockerfile -f $dockerBuildImageName, $repoFolderName, $ContainerRepoLocation | Out-File -FilePath $addRepoDockerFilePath -Encoding ascii -Force

                $null = Invoke-Docker -command build -params '--tag', $ImageName, $dockerBuildFolder
            }
            finally
            {
                if(Test-Path $dockerBuildFolder)
                {
                    Remove-Item -Path $dockerBuildFolder -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    } 
    catch
    {
        Write-VstsError $_
    }
}

# Builds a Docker container
function Invoke-DockerBuild
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $ImageName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $RepoLocation,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ContainerRepoLocation,

        [ValidateNotNullOrEmpty()]
        [string] $Destination = (Get-Destination),

        [string[]] $DockerOptions,

        [string] $BuildCommand,

        [hashtable] $Parameters
    )
    $runtimeParameters = $Parameters.Clone()
    $runtimeParameters['RepoDestinationPath']=$BuildData.RepoDestinationPath

    $ErrorActionPreference = 'Stop'

    try {
        
        if($IsWindows)
        {
            $outputFolder = 'C:\out'
        }
        else 
        {
            $outputFolder = '/mnt'
        }
        $runtimeParameters['DockerVolume']=$outputFolder
        
        if(!(Test-Path $destination))
        {
            $null = New-Item -Path $destination -ItemType Directory -Force
        }

        $dockerContainerName = 'pswscbuild'       

        $params = @('-i', '--name', $dockerContainerName)

        if($DockerOptions)
        {
            $params += $DockerOptions
        }

        $params += $imageName
        $runtimeBuildCommand = [System.Text.StringBuilder]::new($BuildCommand)
        foreach($key in $runtimeParameters.Keys)
        {
            $token = "_${key}_"
            $value = $runtimeParameters.$key
            $null = $runtimeBuildCommand.Replace($token,$value)
        }

        $runtimeBuildCommandString = $runtimeBuildCommand.ToString()
        foreach($param in $runtimeBuildCommandString -split ' ')
        {
            $params += $param
        }

        # Cleanup any existing container from previous runs before starting
        # Ignore failure, because it will fail if they do not exist
        Remove-Container -FailureAction ignore

        $null = Invoke-Docker -command run -params $params

        log "coping artifacts from container" -verbose
        $null = Invoke-Docker -command 'container', 'cp' -params "${dockerContainerName}:$outputFolder", $Destination

        # We are done with the containers, remove them
        Remove-Container 
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
    log "Running docker $command $params"
    $dockerErrors = $null
    if($SupressHostOutput.IsPresent)
    {
        $result = &'docker' $command $params 2>&1
    }
    else 
    {
        &'docker' $command $params 2>&1 | Tee-Object -Variable result -ErrorAction SilentlyContinue -ErrorVariable dockerErrors | Out-String -Stream -ErrorAction SilentlyContinue | Write-Host -ErrorAction SilentlyContinue
    }

    if($dockerErrors -and $FailureAction -ne 'ignore')
    {
        foreach($error in $dockerErrors)
        {
            Write-VstsError -Error $error -Type $FailureAction
        }
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
    $filter = Join-Path -Path (Get-Destination) -ChildPath '*'
    log "Publishing artifacts: $filter"

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

function Write-VstsError {
    param(
        [Parameter(Mandatory=$true)]
        [Object]
        $Error,
        [ValidateSet("error","warning")]
        $Type = 'error'
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
            log "errorType: $errorType"
            $message =  $Error.ToString()
        }
    }
    $message.Split($newLine) | ForEach-Object {
        Write-VstsMessage -type $Type -message $PSItem
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

# this function wraps native command Execution
# for more information, read https://mnaoumov.wordpress.com/2015/01/11/execution-of-external-commands-in-powershell-done-right/
function script:Start-NativeExecution([scriptblock]$sb, [switch]$IgnoreExitcode)
{
    log "Running $($sb.ToString())"
    $backupEAP = $script:ErrorActionPreference
    $script:ErrorActionPreference = "Continue"
    try {
        & $sb
        # note, if $sb doesn't have a native invocation, $LASTEXITCODE will
        # point to the obsolete value
        if ($LASTEXITCODE -ne 0 -and -not $IgnoreExitcode) {
            throw "Execution of {$sb} failed with exit code $LASTEXITCODE"
        }
    } finally {
        $script:ErrorActionPreference = $backupEAP
    }
}

function script:log([string]$message) {
    Write-Host -Foreground Green $message
    #reset colors for older package to at return to default after error message on a compilation error
    [console]::ResetColor()
}

function script:logerror([string]$message) {
    Write-Host -Foreground Red $message
    #reset colors for older package to at return to default after error message on a compilation error
    [console]::ResetColor()
}

Export-ModuleMember @(
    'Invoke-PSBuildContainer'
    'Invoke-PSDockerBuild'
    'Invoke-PSPublishBuildArtifact'
    'Write-VstsError'
    'Clear-VstsTaskState'
    'Write-VstsTaskState'
    'Invoke-Build'
)