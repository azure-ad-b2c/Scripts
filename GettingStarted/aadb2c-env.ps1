param (
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('n')][string]$PolicyPrefix = "",  
    [Parameter(Mandatory=$false)][Alias('k')][boolean]$KeepPolicyIds = $False,  
    [Parameter(Mandatory=$false)][Alias('c')][string]$ConfigPath = "" 
    )

if ( "" -eq $PolicyPath ) {
    $PolicyPath = (get-location).Path
}
if ( "" -eq $ConfigPath ) {
    $ConfigPath = "$PolicyPath\b2cAppSettings.json"
}
if ( "" -eq $PolicyPrefix -and $True -ne $KeepPolicyIds ) {
    $PolicyPrefix = (Get-Item -Path ".\").Name
}
$global:PolicyPath = $PolicyPath
$global:PolicyPrefix = $PolicyPrefix
$global:b2cAppSettings =(Get-Content -Path $ConfigPath | ConvertFrom-json)

$env:B2CAppId=$b2cAppSettings.ClientCredentials.client_id
$env:B2CAppKey=$b2cAppSettings.ClientCredentials.client_secret
$global:B2CAppId=$b2cAppSettings.ClientCredentials.client_id
$global:B2CAppKey=$b2cAppSettings.ClientCredentials.client_secret

if ( $null -ne $b2cAppSettings.AzureStorageAccount ) {
    $global:uxStorageAccount=$b2cAppSettings.AzureStorageAccount.AccountName
    $global:uxStorageAccountKey=$b2cAppSettings.AzureStorageAccount.AccountKey
    $global:uxTemplateLocation= "$($b2cAppSettings.AzureStorageAccount.ContainerName)/$($b2cAppSettings.AzureStorageAccount.Path)/" + $PolicyPrefix.ToLower()
    $global:EndpointSuffix=$b2cAppSettings.AzureStorageAccount.EndpointSuffix
    $global:storageConnectString="DefaultEndpointsProtocol=https;AccountName=$uxStorageAccount;AccountKey=$uxStorageAccountKey;EndpointSuffix=$EndpointSuffix"    
}

try {
        $tenant = Get-AzureADTenantDetail
} catch {
    write-output "Not logged in to a B2C tenant.`n Please run Connect-AzAccount -t {tenantId} or `n$PSScriptRoot\aadb2c-login.ps1 -t `"yourtenant`"`n`n"
    exit 1
}
$tenantName = $tenant.VerifiedDomains[0].Name
$global:tenantName = $tenantName
$tenantID = $tenant.ObjectId
$global:tenantID = $tenantID

write-output "Config File    :`t$ConfigPath"
write-output "B2C Tenant     :`t$tenantID, $tenantName"
write-output "B2C Client Cred:`t$($env:B2CAppId), $($app.DisplayName)"
write-output "Policy Prefix  :`t$PolicyPrefix"


