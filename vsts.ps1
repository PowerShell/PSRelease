param(
    # Begin one switch per parameter set
    [Parameter(ParameterSetName='BuildContainer',Mandatory=$true)]
    [Switch]
    $BuildContainer,

    [Parameter(ParameterSetName='Build',Mandatory=$true)]
    [Switch]
    $Build,

    [Parameter(ParameterSetName='PublishArtifacts',Mandatory=$true)]
    [Switch]
    $PublishArtifacts,

    # end switches
    # begin parameters
    [Parameter(ParameterSetName='BuildContainer',Mandatory=$true)]
    [Parameter(ParameterSetName='Build',Mandatory=$true)]
    [string]
    $Image,

    [Parameter(ParameterSetName='Build',Mandatory=$true)]
    [String]
    $Runtime,

    [Parameter(ParameterSetName='Build')]
    [switch]
    $AppImage,

    [Parameter(ParameterSetName='Build')]
    [ValidatePattern("^v\d+\.\d+\.\d+(-\w+\.\d+)?$")]
    [string]$ReleaseTag,

    [Parameter(ParameterSetName='Build')]
    [String]
    $Branch
)

Write-Verbose 'In VSTS wrapper...' -Verbose
Push-Location
try 
{
    Set-Location $PSScriptRoot

    Import-Module "$PSScriptRoot\psrelease.psm1"
    Clear-VstsTaskState
    switch($PSCmdlet.ParameterSetName)
    {
        'BuildContainer' {
            Write-Verbose 'Calling Build Container ...' -Verbose
            Invoke-PSBuildContainer -image $Image
        }

        'Build' {
            $releaseTagParam = @{}
            if($ReleaseTag)
            {
                $releaseTagParam = @{ 'ReleaseTag' = $ReleaseTag }
            }

            if($Branch)
            {
                $releaseTagParam += @{ 'Branch' = $Branch }
            }

            Write-Verbose 'Calling PowerShell Build ...' -Verbose            
            Invoke-PSDockerBuild -image $Image -Runtime $Runtime -AppImage:$AppImage.IsPresent @releaseTagParam
        }

        'PublishArtifacts' {
            Write-Verbose 'Calling Publish Artifacts ...' -Verbose            
            Invoke-PSPublishBuildArtifact
        }

        default {
            throw 'Unknown parameterSet passed to vsts.ps1'
        }
    }
}
catch
{
    Write-VstsError -Error $_
}
finally{
    Pop-Location
    Write-VstsTaskState
    exit 0
}
