param (
    [Parameter(Mandatory=$true)][Alias('p')][string]$PolicyFile,
    [Parameter(Mandatory=$true)][Alias('n')][string]$WebAppName = "",
    [Parameter(Mandatory=$false)][Alias('r')][string]$redirect_uri = "https://jwt.ms",
    [Parameter(Mandatory=$false)][Alias('s')][string]$scopes = "",
    [Parameter(Mandatory=$false)][boolean]$AzureCli = $False         # if to force Azure CLI on Windows
    )

if (!(Test-Path $PolicyFile -PathType leaf)) {
    write-error "File does not exists: $PolicyFile"
    exit 1
}
if ( $env:PATH -imatch "/usr/bin" ) {                           # Mac/Linux
    $isWinOS = $false
} else {
    $isWinOS = $true
}

[xml]$xml = Get-Content $PolicyFile
$PolicyId = $xml.TrustFrameworkPolicy.PolicyId
$tenantName = $xml.TrustFrameworkPolicy.TenantId

$isSAML = $false
if ( "SAML2"-ne $xml.TrustFrameworkPolicy.RelyingParty.TechnicalProfile.Protocol.Name ) {
    $isSAML = $false
} else {
    $isSAML = $true
}

write-host "Getting test app $WebAppName"
if ( $False -eq $isWinOS -or $True -eq $AzureCli ) {
    $app = (az ad app list --display-name $WebAppName | ConvertFrom-json)
} else {
    $app = Get-AzureADApplication -SearchString $WebAppName -ErrorAction SilentlyContinue
}

if ( $null -eq $app ) {
    write-error "App isn't registered: $WebAppName"
    exit 1
}
if ( $app.Count -gt 1 ) {
    $app = ($app | where {$_.DisplayName -eq $WebAppName})
}
if ( $app.Count -gt 1 ) {
    write-error "App name isn't unique: $WebAppName"
    exit 1
}

$pgm = "chrome.exe"
$params = "--incognito --new-window"

if ( $isSAML) {
    if ( $app.IdentifierUris.Count -gt 1 ) {
        $Issuer = ($app.IdentifierUris | where { $_ -imatch $tenantName })
    } else {
        $Issuer = $app.IdentifierUris[0]
    }
    $url = "https://samltestapp4.azurewebsites.net/SP?Tenant={0}&Policy={1}&Issuer={2}" -f $tenantName, $PolicyId, $Issuer
    # start with Firefox if installed as it has a good extension 'SAML tracer'
    if ( Test-Path "$env:ProgramFiles\Mozilla Firefox" ) {
        $pgm = "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
        $params = "-private -new-window"
    }
} else {
    $scope = "openid"
    $response_type = "id_token"
    # if extra scopes passed on cmdline, then we will also ask for an access_token
    if ( "" -ne $scopes ) {
        $scope = "openid offline_access $scopes"
        $response_type = "id_token token"
    }
    $qparams = "client_id={0}&nonce={1}&redirect_uri={2}&scope={3}&response_type={4}&prompt=login&disable_cache=true" `
                -f $app.AppId.ToString(), (New-Guid).Guid, $redirect_uri, $scope, $response_type
    # Q&D urlencode
    $qparams = $qparams.Replace(":","%3A").Replace("/","%2F").Replace(" ", "%20")

    $url = "https://{0}.b2clogin.com/{1}/{2}/oauth2/v2.0/authorize?{3}" -f $tenantName.Split(".")[0], $tenantName, $PolicyId, $qparams
}

write-host "Starting Browser`n$url"

if ( !$isWinOS) {
    $ret = [System.Diagnostics.Process]::Start("/usr/bin/open","$url")
} else {
    $ret = [System.Diagnostics.Process]::Start($pgm,"$params $url")
}
