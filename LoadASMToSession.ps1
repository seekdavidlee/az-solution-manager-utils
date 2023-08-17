$modulePath = ";" + (Get-Location).Path
$env:PSModulePath += $modulePath
$env:PSModulePath -Split ";"
Import-Module -Name ((Get-Location).Path + "\ASMUtil.psm1") -Verbose
