# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$moduleName = 'dockerBasedBuild.common'
$modulePath = "$PSScriptRoot\..\dockerBasedBuild\$moduleName.psm1"
Import-module $modulePath -force -Scope Local
$vstsModuleName = 'vstsBuild'
$modulePath = "$PSScriptRoot\..\$vstsModuleName"
Import-module $modulePath -force

Describe "DockerBasedBuild.Common" {
    Context "Invoke-BuildInDocker -ArtifactAsFolder" {
        BeforeAll{
            $buildData = New-BuildData
            $buildData.EnableFeature = @('ArtifactAsFolder')
            $buildData.DockerFile = 'TestDockerFile'
            $buildData.DockerImageName = 'TestImageName'
            $buildData.RepoDestinationPath = '/test'
            $buildData.BuildCommand = './TestBuildCommand.sh'
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

    Context "Invoke-BuildInDocker" {
        BeforeAll{
            $buildData = New-BuildData
            $buildData.DockerFile = 'TestDockerFile'
            $buildData.DockerImageName = 'TestImageName'
            $buildData.RepoDestinationPath = '/test'
            $buildData.BuildCommand = './TestBuildCommand.sh'
            $emptyScriptBlock = {}
            Mock -CommandName 'New-DockerImage' -MockWith $emptyScriptBlock -Verifiable -ModuleName $moduleName
            Mock -CommandName 'Invoke-DockerBuild' -MockWith $emptyScriptBlock -Verifiable -ModuleName $moduleName
            Mock -CommandName 'Publish-VstsBuildArtifact' -MockWith $emptyScriptBlock -ModuleName $moduleName
        }

        It "Verify EnableFeature without ArtifactAsFolder does not trigger that feature" {
            Invoke-BuildInDocker -BuildData $buildData -RepoLocation $TestDrive
            Assert-VerifiableMock
            Assert-MockCalled -CommandName 'Publish-VstsBuildArtifact' -ParameterFilter {
                !$ArtifactAsFolder
            } -ModuleName $moduleName
        }
    }

    Context "Get-EngineType" {
        Context "Use AzDevOps docker" {

            It "Should return moby on AzDevOps" {
                if (!$env:TF_BUILD) {
                    Set-ItResult -Skipped -Because "Only test an Azure Dev Ops"
                }
                $expectedResult = 'Moby'
                if ($IsWindows) {
                    $expectedResult = 'Docker'
                }

                Get-EngineType -NoCache -Verbose | Should -Be $expectedResult
            }
        }

        Context "Use mocked moby engine" {
            BeforeAll{
                Mock -CommandName 'docker' -MockWith {""} -Verifiable -ModuleName $moduleName
            }

            It "Should return moby" {
                $result = Get-EngineType -NoCache
                Assert-VerifiableMock
                $result | Should -Be 'Moby'
            }
        }
        Context "Use mocked docker engine" {
            BeforeAll{
                Mock -CommandName 'docker' -MockWith {"Docker fake server platform"} -Verifiable -ModuleName $moduleName
            }

            It "Should return docker" {
                $result = Get-EngineType -NoCache
                Assert-VerifiableMock
                $result | Should -Be 'Docker'
            }
        }
        Context "Use Cache" {
            It "Should return moby" {
                $result = Get-EngineType
                $result | Should -Be 'Docker'
            }
        }
    }
}
