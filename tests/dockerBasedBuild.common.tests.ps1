# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$moduleName = 'dockerBasedBuild.common'
$modulePath = "$PSScriptRoot\..\dockerBasedBuild\$moduleName.psm1"
Import-module $modulePath -force -Scope Local
$vstsModuleName = 'vstsBuild'
$modulePath = "$PSScriptRoot\..\$vstsModuleName"
Import-module $modulePath -force

Describe "DockerBasedBuild.Common" {
    $buildData = New-BuildData
    $buildData.EnableFeature = @('ArtifactAsFolder')
    $buildData.DockerFile = 'TestDockerFile'
    $buildData.DockerImageName = 'TestImageName'
    $buildData.RepoDestinationPath = '/test'
    $buildData.BuildCommand = './TestBuildCommand.sh'


    Context "Invoke-BuildInDocker" {
        BeforeAll{
            $emptyScriptBlock = {}
            Mock -CommandName 'New-DockerImage' -MockWith $emptyScriptBlock -Verifiable -ModuleName $moduleName
            Mock -CommandName 'Invoke-DockerBuild' -MockWith $emptyScriptBlock -Verifiable -ModuleName $moduleName
            Mock -CommandName 'Publish-VstsBuildArtifact' -MockWith $emptyScriptBlock -ModuleName $moduleName
        }

        It "Verify EnableFeature with ArtifactAsFolder triggers that feature" {
            Invoke-BuildInDocker -BuildData $buildData -RepoLocation $TestDrive
            Assert-VerifiableMock
            Assert-MockCalled -CommandName 'Publish-VstsBuildArtifact' -ParameterFilter {
                $ArtifactAsFolder -eq $true
            } -ModuleName $moduleName
        }
    }
}
