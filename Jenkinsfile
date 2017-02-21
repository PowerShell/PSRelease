withEnv(["BRANCH=master"]) {

	stage('Build_Package_Publish') {

		parallel windows: {

			node('Slave-Win-01') {		

				bat 'powershell -c "Remove-Item c:/PSCI -ErrorAction SilentlyContinue -Recurse -Force; exit 0"'
				bat 'git clone -b master https://github.com/raghushantha/PSCI.git c:/PSCI'    
				bat 'powershell -f "c:/PSCI/Bootstrap.ps1"'
				bat 'cd c:/PSCI/ & powershell -f c:/PSCI/GenerateWindowsPackages.ps1 -branch %BRANCH% -Runtime win10-x64 -destinationPath %WORKSPACE%'
				bat 'cd c:/PSCI/ & powershell -f c:/PSCI/GenerateWindowsPackages.ps1 -branch %BRANCH% -Runtime win81-x64 -destinationPath %WORKSPACE%'
				bat 'cd c:/PSCI/ & powershell -f c:/PSCI/GenerateWindowsPackages.ps1 -branch %BRANCH% -Runtime win7-x64 -destinationPath %WORKSPACE%'
				bat 'cd c:/PSCI/ & powershell -f c:/PSCI/GenerateWindowsPackages.ps1 -branch %BRANCH% -Runtime win7-x86 -destinationPath %WORKSPACE%'

				archiveArtifacts '*.msi'
				archiveArtifacts '*.zip'

			}
		},

		linux: {

			node('Lnx-Slave-01') {			

				sh "rm -r -f /tmp/PSCI"
				sh "find $WORKSPACE -type f -exec rm '{}' ';'"
				sh "git clone -b master https://github.com/raghushantha/PSCI.git /tmp/PSCI"
				sh "docker build --force-rm --tag microsoft/powershell:ubuntu14.04 /tmp/PSCI/Images/microsoft_powershell_ubuntu14.04"
				sh "docker build --force-rm --tag microsoft/powershell:ubuntu16.04 /tmp/PSCI/Images/microsoft_powershell_ubuntu16.04"
				sh "docker build --force-rm --tag microsoft/powershell:centos7 /tmp/PSCI/Images/microsoft_powershell_centos7"			
				sh "docker run --rm --volume /tmp/PSCI:/mnt microsoft/powershell:ubuntu14.04 -c \"powershell -c \"/PowerShellPackage.ps1 -branch $BRANCH\" \""
				sh "docker run --rm --volume /tmp/PSCI:/mnt microsoft/powershell:ubuntu16.04 -c \"powershell -c \"/PowerShellPackage.ps1 -branch $BRANCH\" \""
				sh "docker run --rm --volume /tmp/PSCI:/mnt microsoft/powershell:centos7 -c \"powershell -c \"/PowerShellPackage.ps1 -branch $BRANCH\" \""

				sh "find /tmp/PSCI -name '*.deb' -exec cp -prv '{}' $WORKSPACE ';'"
				sh "find /tmp/PSCI -name '*.rpm' -exec cp -prv '{}' $WORKSPACE ';'"			

				archiveArtifacts '*.deb'
				archiveArtifacts '*.rpm'

			}
		}
	}
}
