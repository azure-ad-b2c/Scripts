param (
    [Parameter(Mandatory=$true)][Alias('p')][string]$PolicyFile,
    [Parameter(Mandatory=$true)][Alias('n')][string]$WebAppName = "",
    [Parameter(Mandatory=$false)][Alias('i')][string]$Issuer = "",
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

if ( "SAML2"-ne $xml.TrustFrameworkPolicy.RelyingParty.TechnicalProfile.Protocol.Name ) {
    write-error "This is not a SAML 2 protocol policy"
    exit 2
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

if ( $app.IdentifierUris.Count -gt 1 ) {
    $Issuer = ($app.IdentifierUris | where { $_ -imatch $tenantName })
} else {
    $Issuer = $app.IdentifierUris[0]
}

$url = "https://samltestapp4.azurewebsites.net/SP?Tenant={0}&Policy={1}&Issuer={2}" -f $tenantName, $PolicyId, $Issuer

write-host "Starting Browser`n$url"

if ( !$isWinOS) {
    $ret = [System.Diagnostics.Process]::Start("/usr/bin/open","$url")
} else {
    $pgm = "chrome.exe"
    $params = "--incognito --new-window"
    # start with Firefox if installed as it has a good extension 'SAML tracer'
    if ( Test-Path "$env:ProgramFiles\Mozilla Firefox" ) {
        $pgm = "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
        $params = "-private -new-window"
    }
    $ret = [System.Diagnostics.Process]::Start($pgm,"$params $url")
}
