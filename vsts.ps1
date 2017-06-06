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

try 
{
    Import-Module "$PSScriptRoot\psrelease.psm1"
    Clear-VstsTaskState
    switch($PSCmdlet.ParameterSetName)
    {
        'BuildContainer' {
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

            Invoke-PSDockerBuild -image $Image -Runtime $Runtime -AppImage:$AppImage.IsPresent @releaseTagParam
        }

        'PublishArtifacts' {
            Invoke-PSPublishBuildArtifact
        }

        default {
            throw 'Unknow parameterset passed to vsts.ps1'
        }
    }
}
catch
{
    Write-VstsError -Error $_
}
finally{
    Write-VstsTaskState
    exit 0
}
