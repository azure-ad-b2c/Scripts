param (
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('a')][string]$AppID = "",
    [Parameter(Mandatory=$false)][Alias('k')][string]$AppKey = "",
    [Parameter(Mandatory=$true)][Alias('n')][string]$AppDisplayName = ""
    )

$oauth = $null
if ( "" -eq $AppID ) { $AppID = $env:B2CAppId }
if ( "" -eq $AppKey ) { $AppKey = $env:B2CAppKey }

$tenantID = ""
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
if ( "" -eq $tenantID ) {
    write-host "Unknown Tenant"
    exit 2
}
write-host "Tenant:  `t$tenantName`nTenantID:`t$tenantId"

$app = Get-AzureADApplication -All $true | where-object {$_.DisplayName -eq $AppDisplayName } -ErrorAction SilentlyContinue
$sp = Get-AzureADServicePrincipal -All $true | where-object {$_.DisplayName -eq $AppDisplayName } -ErrorAction SilentlyContinue

if ( $null -eq $app -or $null -eq $sp ) {
    write-output "No ServicePrincipal with name $AppDisplayName"
    exit 1
}

$oauthBody  = @{grant_type="client_credentials";resource="https://graph.microsoft.com/";client_id=$AppID;client_secret=$AppKey;scope="https://graph.microsoft.com/.default"}
$oauth      = Invoke-RestMethod -Method Post -Uri "https://login.microsoft.com/$tenantName/oauth2/token?api-version=1.0" -Body $oauthBody

$startTime = (get-date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$expiryTime = ((get-date).AddYears(2)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$scope = ""
foreach( $reqResAccess in $app.RequiredResourceAccess ) { 
    $resource = (Get-AzureADServicePrincipal -All $true | where-object {$_.AppId -eq $reqResAccess.ResourceAppId })
    $ResourceObjectId = $resource.ObjectId
    foreach( $ra in $reqResAccess.ResourceAccess ) {
        $scope += ($resource.oauth2Permissions | where-object {$_.Id -eq $ra.Id}).Value + " "
    }
    $body = @{
        clientId    = $sp.ObjectId
        consentType = "AllPrincipals"
        principalId = $null
        resourceId  = $ResourceObjectId
        scope       = $scope
        startTime   = $startTime
        expiryTime  = $expiryTime 
    }
    write-output "Granting $($resource.DisplayName) - $scope to $AppDisplayName"
    $apiUrl = "https://graph.microsoft.com/beta/oauth2PermissionGrants"
    Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization = "Bearer $($oauth.access_token)" }  -Method POST -Body $($body | convertto-json) -ContentType "application/json"
}

