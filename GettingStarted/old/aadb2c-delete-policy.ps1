param (
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('f')][string]$PolicyFile = "",
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('a')][string]$AppID = "",
    [Parameter(Mandatory=$false)][Alias('k')][string]$AppKey = "",
    [Parameter(Mandatory=$false)][boolean]$AzureCli = $False         # if to force Azure CLI on Windows
    )

$oauth = $null
if ( "" -eq $AppID ) { $AppID = $env:B2CAppId }
if ( "" -eq $AppKey ) { $AppKey = $env:B2CAppKey }
if ( "" -eq $TenantName ) { $TenantName = $global:TenantName }
if ( $env:PATH -imatch "/usr/bin" ) {                           # Mac/Linux
    $isWinOS = $false
} else {
    $isWinOS = $true
}

# invoke the Graph REST API to upload the Policy
Function DeletePolicy( [string]$PolicyId) {
    # https://docs.microsoft.com/en-us/graph/api/trustframework-put-trustframeworkpolicy?view=graph-rest-beta
    # Delete the Custom Policy
    write-host "Deleteing policy $PolicyId..."
    $url = "https://graph.microsoft.com/beta/trustFramework/policies/$PolicyId"
    $resp = Invoke-RestMethod -Method DELETE -Uri $url -Headers @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"}
}

# either try and use the tenant name passed or grab the tenant from current session
<##>
$tenantID = ""
$resp = Invoke-RestMethod -Uri "https://login.windows.net/$TenantName/v2.0/.well-known/openid-configuration"
$tenantID = $resp.authorization_endpoint.Split("/")[3]    

<##>
if ( "" -eq $tenantID ) {
    write-host "Unknown Tenant"
    exit 2
}
write-host "Tenant:  `t$tenantName`nTenantID:`t$tenantId"

# check the B2C Graph App passed
if ( $False -eq $isWinOS -or $True -eq $AzureCli ) {
    $app = (az ad app show --id $AppID | ConvertFrom-json)
} else {
    $app = Get-AzureADApplication -Filter "AppID eq '$AppID'"
}
if ( $null -eq $app ) {
    write-host "App not found in B2C tenant: $AppID"
    exit 3
} else {
    write-host "`Authenticating as App $($app.DisplayName), AppID $AppID"
}
<##>
if ( "" -eq $PolicyPath ) {
    $PolicyPath = (get-location).Path
}

# https://docs.microsoft.com/en-us/azure/active-directory/users-groups-roles/directory-assign-admin-roles#b2c-user-flow-administrator
# get an access token for the B2C Graph App
$oauthBody  = @{grant_type="client_credentials";resource="https://graph.microsoft.com/";client_id=$AppID;client_secret=$AppKey;scope="Policy.ReadWrite.TrustFramework"}
$oauth      = Invoke-RestMethod -Method Post -Uri "https://login.microsoft.com/$tenantName/oauth2/token?api-version=1.0" -Body $oauthBody

if ( "" -ne $PolicyFile ) {
    $PolicyData = Get-Content $PolicyFile # 
    [xml]$xml = $PolicyData
    DeletePolicy $xml.TrustFrameworkPolicy.PolicyId
} else {
    $files = get-childitem -path $PolicyPath -name -include *.xml | Where-Object {! $_.PSIsContainer }
    foreach( $file in $files ) {
        #write-output "Reading Policy XML file $file..."
        $PolicyFile = (Join-Path -Path $PolicyPath -ChildPath $file)
        $PolicyData = Get-Content $PolicyFile
        [xml]$xml = $PolicyData
        if ( $tenantName -ne $xml.TrustFrameworkPolicy.TenantId ) {
            write-warning $xml.TrustFrameworkPolicy.PublicPolicyUri " is not in the current tenant $tenantName"
        } else {
            DeletePolicy $xml.TrustFrameworkPolicy.PolicyId
        }
    }
}
