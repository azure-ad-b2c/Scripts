param (
    [Parameter(Mandatory=$false)][Alias('t')][string]$Tenant = "",
    [Parameter(Mandatory=$false)][boolean]$AzureCli = $False         # if to force Azure CLI on Windows
    )

if ( $env:PATH -imatch "/usr/bin" ) {                           # Mac/Linux
    $isWinOS = $false
} else {
    $isWinOS = $true
}
if ( $Tenant.Length -eq 36 -and $Tenant.Contains("-") -eq $true)  {
    $TenantID = $Tenant
} else {
    if ( !($Tenant -imatch ".onmicrosoft.com") ) {
        $Tenant = $Tenant + ".onmicrosoft.com"
    }
    $url = "https://login.windows.net/$Tenant/v2.0/.well-known/openid-configuration"
    $resp = Invoke-RestMethod -Uri $url
    $TenantID = $resp.authorization_endpoint.Split("/")[3]    
    write-output $TenantID
}

$startTime = Get-Date

if ( $False -eq $isWinOS -or $True -eq $AzureCli ) {
    $ctx = (az login --tenant $Tenant --allow-no-subscriptions | ConvertFrom-json)
    $Tenant = $ctx[0].tenantId
    $user = $ctx[0].user.name
    $type = "CLI"
} else {                                                        # Windows
    $ctx = Connect-AzureAD -tenantid $TenantID
    $Tenant = $ctx.TenantDomain
    $user = $ctx.Account.Id
    $type = ""
}

$finishTime = Get-Date
$TotalTime = ($finishTime - $startTime).TotalSeconds
Write-Output "Time: $TotalTime sec(s)"        

write-output $ctx

$host.ui.RawUI.WindowTitle = "PS AAD $type - $user - $Tenant"
