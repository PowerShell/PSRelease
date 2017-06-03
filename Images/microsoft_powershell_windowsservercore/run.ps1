$name = 'pscorebuild'
Write-Verbose "stopping any $name running containers..." -Verbose
get-container $name | Stop-Container -ErrorAction SilentlyContinue
Write-Verbose "removing any $name existing containers..." -Verbose
get-container $name | Remove-Container

#$null = new-item D:\ps_output\powershell
Write-Verbose "Starting the psbuild container..." -Verbose
docker run --name $name -iv D:\ps_output:C:\v -m 3968m psrel/wsc .\GenerateWindowsPackages.ps1 -branch master -location C:\powershell  -destinationPath C:\v\out -Runtime win10-x64
