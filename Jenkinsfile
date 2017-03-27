withEnv(["BRANCH=master"]) {

	stage('Build_Package_Publish') {

		parallel windows: {

			node('Slave-Win-01') {		

				bat 'powershell -c "Remove-Item c:/PSRelease -ErrorAction SilentlyContinue -Recurse -Force; exit 0"'
				bat 'powershell -c "Remove-Item "$env:WORKSPACE/*" -ErrorAction SilentlyContinue -Recurse -Force; exit 0"'
				bat 'git clone -b master https://github.com/powershell/PSRelease.git c:/PSRelease'
				bat 'cd c:/PSRelease/ & powershell -f c:/PSRelease/GenerateWindowsPackages.ps1 -branch %BRANCH% -Runtime win10-x64 -destinationPath %WORKSPACE%'
				bat 'cd c:/PSRelease/ & powershell -f c:/PSRelease/GenerateWindowsPackages.ps1 -branch %BRANCH% -Runtime win81-x64 -destinationPath %WORKSPACE%'
				bat 'cd c:/PSRelease/ & powershell -f c:/PSRelease/GenerateWindowsPackages.ps1 -branch %BRANCH% -Runtime win7-x64 -destinationPath %WORKSPACE%'
				bat 'cd c:/PSRelease/ & powershell -f c:/PSRelease/GenerateWindowsPackages.ps1 -branch %BRANCH% -Runtime win7-x86 -destinationPath %WORKSPACE%'

				archiveArtifacts '*.msi'
				archiveArtifacts '*.zip'

			}
		},

		linux: {

			node('Lnx-Slave-01') {			

				sh "rm -r -f /tmp/PSRelease"
				sh "find $WORKSPACE -type f -exec rm '{}' ';'"
				sh "git clone -b master https://github.com/powershell/PSRelease.git /tmp/PSRelease"				

				sh "docker build --force-rm --tag microsoft/powershell:ubuntu14.04 /tmp/PSRelease/Images/microsoft_powershell_ubuntu14.04"
				sh "docker build --force-rm --tag microsoft/powershell:ubuntu16.04 /tmp/PSRelease/Images/microsoft_powershell_ubuntu16.04"
				sh "docker build --force-rm --tag microsoft/powershell:centos7 /tmp/PSRelease/Images/microsoft_powershell_centos7"
				sh "docker build --force-rm --tag microsoft/powershell:opensuse42.1 /tmp/PSRelease/Images/microsoft_powershell_opensuse42.1"
				
				sh "docker run --rm --cap-add SYS_ADMIN --cap-add MKNOD --device=/dev/fuse --security-opt apparmor:unconfined --volume /tmp/PSRelease:/mnt microsoft/powershell:ubuntu14.04 -c \"powershell -c \"/PowerShellPackage.ps1 -branch $BRANCH\" \""
				sh "docker run --rm --volume /tmp/PSRelease:/mnt microsoft/powershell:ubuntu16.04 -c \"powershell -c \"/PowerShellPackage.ps1 -branch $BRANCH\" \""
				sh "docker run --rm --volume /tmp/PSRelease:/mnt microsoft/powershell:centos7 -c \"powershell -c \"/PowerShellPackage.ps1 -branch $BRANCH\" \""
				sh "docker run --rm --volume /tmp/PSRelease:/mnt microsoft/powershell:opensuse42.1 -c \"powershell -c \"/PowerShellPackage.ps1 -branch $BRANCH\" \""
        
				sh "find /tmp/PSRelease -name '*.deb' -exec cp -prv '{}' $WORKSPACE ';'"
				sh "find /tmp/PSRelease -name '*.rpm' -exec cp -prv '{}' $WORKSPACE ';'"			
				sh "find /tmp/PSRelease -name '*.AppImage' -exec cp -prv '{}' $WORKSPACE ';'"

				archiveArtifacts '*.deb'
				archiveArtifacts '*.rpm'
				archiveArtifacts '*.AppImage'

			}
		}
	}
}
