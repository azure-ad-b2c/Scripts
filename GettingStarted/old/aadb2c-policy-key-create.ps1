param (
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('a')][string]$AppID = "",            # App reg in B2C that has permissions to create policy keys
    [Parameter(Mandatory=$false)][Alias('k')][string]$AppKey = "",           #
    [Parameter(Mandatory=$true)][Alias('n')][string]$KeyContainerName = "", # [B2C_1A_]Name
    [Parameter(Mandatory=$true)][Alias('y')][string]$KeyType = "secret",    # RSA, secret
    [Parameter(Mandatory=$true)][Alias('u')][string]$KeyUse = "sig",        # sig, enc
    [Parameter(Mandatory=$false)][Alias('s')][string]$Secret = ""           # used when $KeyType==secret
    )

$oauth = $null
if ( "" -eq $AppID ) { $AppID = $env:B2CAppId }
if ( "" -eq $AppKey ) { $AppKey = $env:B2CAppKey }
$KeyType = $KeyType.ToLower()
$KeyUse = $KeyUse.ToLower()

if ( !("rsa" -eq $KeyType -or "secret" -eq $KeyType ) ) {
    write-output "KeyType must be RSA or secret"
    exit 1
}
if ( !("sig" -eq $KeyUse -or "enc" -eq $KeyUse ) ) {
    write-output "KeyUse must be sig(nature) or enc(ryption)"
    exit 1
}
if ( $false -eq $KeyContainerName.StartsWith("B2C_1A_") ) {
    $KeyContainerName = "B2C_1A_$KeyContainerName"
}

if ( "" -eq $TenantName ) {
    write-host "Getting Tenant info..."
    $tenant = Get-AzureADTenantDetail
    if ( $null -eq $tenant ) {
        write-host "Not logged in to a B2C tenant"
        exit 1
    }
    $tenantName = $tenant.VerifiedDomains[0].Name
    $tenantID = $tenant.ObjectId
} else {
    if ( !($TenantName -imatch ".onmicrosoft.com") ) {
        $TenantName = $TenantName + ".onmicrosoft.com"
    }
    $resp = Invoke-RestMethod -Uri "https://login.windows.net/$TenantName/v2.0/.well-known/openid-configuration"
    $tenantID = $resp.authorization_endpoint.Split("/")[3]    
}

$oauthBody  = @{grant_type="client_credentials";resource="https://graph.microsoft.com/";client_id=$AppID;client_secret=$AppKey;scope="TrustFrameworkKeySet.Read.All,TrustFrameworkKeySet.ReadWrite.All"}
$oauth      = Invoke-RestMethod -Method Post -Uri "https://login.microsoft.com/$tenantName/oauth2/token?api-version=1.0" -Body $oauthBody
<##>
$url = "https://graph.microsoft.com/beta/trustFramework/keySets"

try {
    $resp = Invoke-RestMethod -Method GET -Uri "$url/$KeyContainerName" -Headers @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"} -ErrorAction SilentlyContinue
    write-output "$($resp.id) already has $($resp.keys.Length) keys"
    exit 0
} catch {
}
$body = @"
{
    "id": "$KeyContainerName"
}
"@
$resp = Invoke-RestMethod -Method POST -Uri $url -Headers @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"} -Body $body -ContentType "application/json" -ErrorAction SilentlyContinue
<##>
if ( "secret" -eq $KeyType ) {
    $url = "https://graph.microsoft.com/beta/trustFramework/keySets/$KeyContainerName/uploadSecret"
    $body = @"
{
    "use": "$KeyUse",
    "k": "$Secret"
}
"@
} 
if ( "rsa" -eq $KeyType ) {
    $url = "https://graph.microsoft.com/beta/trustFramework/keySets/$KeyContainerName/generateKey"
    $body = @"
{
    "use": "$KeyUse",
    "kty": "RSA",
}
"@
} 

$resp = Invoke-RestMethod -Method POST -Uri $url -Headers @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"} -Body $body -ContentType "application/json"
write-output "key created: $KeyContainerName"