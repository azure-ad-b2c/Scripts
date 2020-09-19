param (
    [Parameter(Mandatory=$true)][Alias('c')][string]$ConfigPath
    )

$global:b2cAppSettings =(Get-Content -Path $ConfigPath | ConvertFrom-json)

& $PSScriptRoot\aadb2c-login.ps1 -t $b2cAppSettings.TenantName

& $PSScriptRoot\aadb2c-env.ps1 -ConfigPath $ConfigPath
