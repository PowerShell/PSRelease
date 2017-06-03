$path = Join-Path $PSScriptRoot -ChildPath 'delete-to-continue.txt'
$null = New-Item -Path $path -ItemType File
Write-Verbose "Computer name: $env:COMPUTERNAME" -Verbose
Write-Verbose "Delete $path to exit." -Verbose
while(Test-Path -LiteralPath $path)
{
    Start-Sleep -Seconds 60
}