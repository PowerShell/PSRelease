# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# VSTS task states: Succeeded|SucceededWithIssues|Failed|Cancelled|Skipped
$succeededStateName = 'Succeeded'
$warningStateName = 'SucceededWithIssues'
$errorStateName = 'Failed'

# store the current state used by *-VstsTaskState and Write-VstsMessage
$script:taskstate = $succeededStateName

function Clear-VstsTaskState {
    $script:taskstate = $succeededStateName
}

function Get-TempFolder {
    $tempPath = [System.IO.Path]::GetTempPath()
    # Use the agent temp on VSTS which is cleanup between builds (the user temp is not)
    if ($env:AGENT_TEMPDIRECTORY) {
        $tempPath = $env:AGENT_TEMPDIRECTORY
    }

    $tempFolder = Join-Path -Path $tempPath -ChildPath ([System.IO.Path]::GetRandomFileName())
    if (!(test-path $tempFolder)) {
        $null = New-Item -Path $tempFolder -ItemType Directory
    }

    return $tempFolder
}

$script:AlternateStagingDirectory = $null
function Get-StagingDirectory {
    # environment variable are documented here:
    # https://docs.microsoft.com/en-us/vsts/build-release/concepts/definitions/build/variables?tabs=batch
    if ($env:BUILD_STAGINGDIRECTORY) {
        return $env:BUILD_STAGINGDIRECTORY
    }
    else {
        if (!$script:AlternateStagingDirectory) {
            Write-VstsInformation "Cannot find staging directory, logging environment"
            Get-ChildItem env: | ForEach-Object { Write-VstsInformation -message $_ }
            $script:AlternateStagingDirectory = Get-TempFolder
        }
        return $script:AlternateStagingDirectory
    }
}

$script:publishedFiles = @()
# Publishes build artifacts
function Publish-VstsBuildArtifact {
    param(
        [parameter(Mandatory, HelpMessage = "Path to publish artifacts from.")]
        [string]$ArtifactPath,
        [parameter(HelpMessage = "The folder to same artifacts to.")]
        [string]$Bucket = 'release',
        [parameter(HelpMessage = "If an artifact is unzipped, set a variable to the destination path with this name. Only supported with '-ExpectedCount 1'")]
        [string]$Variable,
        [parameter(HelpMessage = "Expected Artifact Count. Will throw if the count does not match. Not specified or -1 will ignore this parameter.")]
        [int]$ExpectedCount = -1,
        [parameter(HelpMessage = "Publish the artifacts as a single folder rather than individual files")]
        [Switch]$PublishAsFolder,
        [parameter(HelpMessage = "Make multiple files published appear as a folder in VSTS")]
        [Switch]$ArtifactAsFolder
    )
    $ErrorActionPreference = 'Continue'
    $filter = Join-Path -Path $ArtifactPath -ChildPath '*'
    Write-VstsInformation -message "Publishing artifacts: $filter"

    if ($PublishAsFolder.IsPresent) {
        $artifactDir = Get-Item -Path $ArtifactPath -ErrorAction SilentlyContinue
        if (!$artifactDir -or $artifactDir -isnot [System.IO.DirectoryInfo]) {
            Write-Error -Message "-ArtifactPath must be a folder which exists" -ErrorAction Stop
        }

        $fullName = $artifactDir.FullName

        Publish-VstsArtifactWrapper -Path $fullName -Bucket $Bucket -ArtifactAsFolder:$ArtifactAsFolder.IsPresent
    }

    # In VSTS, publish artifacts appropriately
    $files = Get-ChildItem -Path $filter -Recurse | Select-Object -ExpandProperty FullName
    $destinationPath = Join-Path (Get-StagingDirectory) -ChildPath $Bucket
    if (-not (Test-Path $destinationPath)) {
        $null = New-Item -Path $destinationPath -ItemType Directory
    }

    foreach ($fileName in $files) {
        # Only publish files once
        if ($script:publishedFiles -inotcontains $fileName) {
            $leafFileName = $(Split-path -Path $fileName -Leaf)

            $extension = [System.IO.Path]::GetExtension($leafFileName)
            $nameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($leafFileName)
            # Only expand the symbol '.zip' package
            if ($extension -ieq '.zip' -and $nameWithoutExtension.Contains("symbols")) {
                $unzipPath = (Join-Path $destinationPath -ChildPath $nameWithoutExtension)
                if ($Variable) {
                    Write-VstsInformation -message "Setting VSTS variable '$Variable' to '$unzipPath'"
                    # Sets a VSTS variable for use in future build steps.
                    Write-Host "##vso[task.setvariable variable=$Variable]$unzipPath"
                    # Set a variable in the current process. PowerShell will not pickup the variable until the process is restarted otherwise.
                    Set-Item env:\$Variable -Value $unzipPath
                }
                Expand-Archive -Path $fileName -DestinationPath $unzipPath
            }

            if (!$PublishAsFolder.IsPresent) {
                Publish-VstsArtifactWrapper -Path $fileName -Bucket $Bucket -ArtifactAsFolder:$ArtifactAsFolder.IsPresent
            }

            $script:publishedFiles += $fileName
        }
    }

    if ($ExpectedCount -ne -1 -and $files.Count -ne $ExpectedCount) {
        throw "Build did not produce the expected number of binaries. $($files.count) were produced instead of $ExpectedCount.  Update the 'ArtifactsExpected' property in 'build.json' if the number of artifacts has changed."
    }
}

function Publish-VstsArtifactWrapper {
    param(
        [parameter(HelpMessage = "The file to publish", Mandatory)]
        [string]$Path,
        [parameter(HelpMessage = "The folder to same artifacts to.")]
        [string]$Bucket = 'release',
        [parameter(HelpMessage = "Make multiple files published appear as a folder in VSTS")]
        [Switch]$ArtifactAsFolder
    )

    $artifactName = Split-Path -Path $Path -Leaf
    if ($ArtifactAsFolder.IsPresent) {
        $artifactName = $Bucket
    }

    Publish-VstsArtifact -Path $Path -Bucket $Bucket -ArtifactName $artifactName
}

function Publish-VstsArtifact {
    param(
        [parameter(HelpMessage = "The file to publish", Mandatory)]
        [string]$Path,
        [parameter(HelpMessage = "The folder to same artifacts to.", Mandatory)]
        [string]$Bucket,
        [parameter(HelpMessage = "The folder to same artifacts to.", Mandatory)]
        [string]$ArtifactName
    )

    if ($env:BUILD_REASON -ne 'PullRequest') {
        Write-Host "##vso[artifact.upload containerfolder=$Bucket;artifactname=$ArtifactName]$Path"
    }
}

function Write-VstsError {
    param(
        [Parameter(Mandatory = $true)]
        [Object]
        $Error,
        [ValidateSet("error", "warning")]
        $Type = 'error'
    )

    $message = [string]::Empty
    $errorType = $Error.GetType().FullName
    $newLine = [System.Environment]::NewLine
    switch ($errorType) {
        'System.Management.Automation.ErrorRecord' {
            $message = "{0}{2}`t{1}" -f $Error, $Error.ScriptStackTrace, $newLine
        }
        'System.Management.Automation.ParseException' {
            $message = "{0}{2}`t{1}" -f $Error, $Error.StackTrace, $newLine
        }
        'System.Management.Automation.Runspaces.RemotingErrorRecord' {
            $message = "{0}{2}`t{1}{2}`tOrigin: {2}" -f $Error, $Error.ScriptStackTrace, $Error.OriginInfo, $newLine
        }
        default {
            # Log any unknown error types we get so  we can improve logging.
            log "errorType: $errorType"
            $message = $Error.ToString()
        }
    }
    $message.Split($newLine) | ForEach-Object {
        Write-VstsMessage -type $Type -message $PSItem
    }
}

# Log messages which potentially change job status
function Write-VstsMessage {
    param(
        [ValidateSet("error", "warning")]
        $type = 'error',
        [String]
        $message
    )

    if ($script:taskstate -ne $errorStateName -and $type -eq 'error') {
        $script:taskstate = $errorStateName
    }
    elseif ($script:taskstate -eq $succeededStateName) {
        $script:taskstate = $warningStateName
    }

    # See VSTS documentation at https://github.com/Microsoft/vsts-tasks/blob/master/docs/authoring/commands.md
    # Log task message
    Write-Host "##vso[task.logissue type=$type]$message"
}

# Log informational messages
function Write-VstsInformation {
    param(
        [String]
        $message
    )

    Write-Host $message
}

function Write-VstsTaskState {
    # See VSTS documentation at https://github.com/Microsoft/vsts-tasks/blob/master/docs/authoring/commands.md
    # Log task state
    Write-Host "##vso[task.complete result=$script:taskstate;]DONE"
}

Export-ModuleMember @(
    'Publish-VstsBuildArtifact'
    'Write-VstsError'
    'Write-VstsMessage'
    'Clear-VstsTaskState'
    'Write-VstsTaskState'
    'Publish-VstsArtifact'
)
