param (
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('n')][string]$PolicyPrefix = "",  
    [Parameter(Mandatory=$false)][Alias('c')][string]$ConfigPath = "",  
    [Parameter(Mandatory=$false)][Alias('s')][boolean]$UploadSecrets = $false  
    )

if ( "" -eq $PolicyPath ) {
    $PolicyPath = (get-location).Path
}
if ( "" -eq $ConfigPath ) {
    $ConfigPath = "$PolicyPath\b2cAppSettings.json"
}
if ( "" -eq $PolicyPrefix ) {
    $PolicyPrefix = (Get-Item -Path ".\").Name
}
$b2cAppSettings =(Get-Content -Path $ConfigPath | ConvertFrom-json)

$env:B2CAppId=$b2cAppSettings.ClientCredentials.client_id
$env:B2CAppKey=$b2cAppSettings.ClientCredentials.client_secret

if ( $null -ne $b2cAppSettings.AzureStorageAccount ) {
    $uxStorageAccount=$b2cAppSettings.AzureStorageAccount.AccountName
    $uxStorageAccountKey=$b2cAppSettings.AzureStorageAccount.AccountKey
    $uxTemplateLocation= "$($b2cAppSettings.AzureStorageAccount.ContainerName)/$($b2cAppSettings.AzureStorageAccount.Path)/" + $PolicyPrefix.ToLower()
    $EndpointSuffix=$b2cAppSettings.AzureStorageAccount.EndpointSuffix
    $storageConnectString="DefaultEndpointsProtocol=https;AccountName=$uxStorageAccount;AccountKey=$uxStorageAccountKey;EndpointSuffix=$EndpointSuffix"    
}

function writeSeparator( $msg ) {
    write-output "*******************************************************************************"
    write-output "* $msg"
    write-output "*******************************************************************************"
}

$tenant = Get-AzureADTenantDetail
if ( $null -eq $tenant ) {
    write-host "Not logged in to a B2C tenant. Please run Connect-AzAccount -t {tenantId}"
    exit 1
}
$tenantName = $tenant.VerifiedDomains[0].Name
$tenantID = $tenant.ObjectId

$app = Get-AzureADApplication -Filter "AppID eq '$($b2cAppSettings.ClientCredentials.client_id)'"
if ( $null -eq $app ) {
    write-host "App not found in B2C tenant: $($b2cAppSettings.ClientCredentials.client_id)"
    exit 3
}

writeSeparator "Configuration"
write-output "Config File    :`t$ConfigPath"
write-output "B2C Tenant     :`t$tenantID, $tenantName"
write-output "B2C Client Cred:`t$($env:B2CAppId), $($app.DisplayName)"
write-output "Policy Prefix  :`t$PolicyPrefix"

# download StarterPack files from github and modify them to refer to your tenant
writeSeparator "Downloading and preparing Starter Pack"
& $PSScriptRoot\aadb2c-prep-starter-pack.ps1 -t $TenantName -x $PolicyPrefix -p $PolicyPath -b $b2cAppSettings.StarterPack `
                        -IefAppName $b2cAppSettings.IefAppName -IefProxyAppName $b2cAppSettings.IefProxyAppName

# add custom attribute app
if ( $null -ne $b2cAppSettings.CustomAttributes -and $true -eq $b2cAppSettings.CustomAttributes.Enabled ) {
    writeSeparator "Adding custom attributes app to AAD-Common Claims Provider"
    & $PSScriptRoot\aadb2c-add-customattribute-app.ps1 -n $b2cAppSettings.CustomAttributes.AppDisplayName `
                                            -a $b2cAppSettings.CustomAttributes.ObjectId -c $b2cAppSettings.CustomAttributes.AppID
}

# add social IdPs
writeSeparator "Adding Social IdPs"
foreach( $cp in $b2cAppSettings.ClaimsProviders ) {
    if ( $true -eq $cp.Enabled ) {
        & $PSScriptRoot\aadb2c-add-claimsprovider.ps1 -i $cp.Name -c $cp.client_id -a $cp.DomainName
        if ( $true -eq $UploadSecrets -and ($null -ne $cp.client_secret -or "" -ne $cp.client_secret) ) {
            & $PSScriptRoot\aadb2c-policy-key-create.ps1 -n $cp.SecretName -s $cp.client_secret -y "secret" -u $cp.use
        }
    }
}

# change content definitions, enable javascript and point UX to our own url
if ( $null -ne $b2cAppSettings.UxCustomization -and $true -eq $b2cAppSettings.UxCustomization.Enabled ) {
    writeSeparator "Enabling Javascript and UX Customization"
    & $PSScriptRoot\aadb2c-policy-ux-customize.ps1 -d $true -u "https://$uxStorageAccount.blob.$EndpointSuffix/$uxTemplateLocation"
}
# upload the Custom Policies to B2C
writeSeparator "Uploading Custom Policies to B2C"
& $PSScriptRoot\aadb2c-upload-policy.ps1 -t $TenantName 

# upload the UX elements to blob storage
if ( $null -ne $b2cAppSettings.UxCustomization -and $true -eq $b2cAppSettings.UxCustomization.Enabled ) {
    writeSeparator "Uploading html files to Azure Blob Storage"
    & $PSScriptRoot\aadb2c-upload-ux-to-storage.ps1 -p "$PolicyPath\html" -s $storageConnectString -c $uxTemplateLocation
}