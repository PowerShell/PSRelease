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
    [Parameter(ParameterSetName='ClonePowerShell',Mandatory=$true)]
    [Switch]
    $ClonePowerShell,

    [Parameter(ParameterSetName='AgentCleanup',Mandatory=$true)]
    [Switch]
    $AgentCleanup,
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
    $AppImage
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
            Invoke-PSDockerBuild -image $Image -Runtime $Runtime -AppImage:$AppImage.IsPresent
        }

        'ClonePowerShell' {
            Invoke-PSClonePowerShell -location $ENV:Build_SourcesDirectory\powershell
        }

        'PublishArtifacts' {
            Invoke-PSPublishBuildArtifact
        }

        'AgentCleanup' {
            Invoke-PSVstsCleanup
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
