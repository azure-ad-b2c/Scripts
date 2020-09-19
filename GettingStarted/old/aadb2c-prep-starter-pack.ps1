param (
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('x')][string]$PolicyPrefix = "",
    [Parameter(Mandatory=$false)][Alias('b')][string]$PolicyType = "SocialAndLocalAccounts",
    [Parameter(Mandatory=$false)][string]$IefAppName = "IdentityExperienceFramework",
    [Parameter(Mandatory=$false)][string]$IefProxyAppName = "ProxyIdentityExperienceFramework"    
    )

& $PSScriptRoot\aadb2c-download-starter-pack.ps1 -p $PolicyPath -b $PolicyType

& $PSScriptRoot\aadb2c-policy-set-tenant.ps1 -t $TenantName -p $PolicyPath -x $PolicyPrefix  `
                -IefAppName $IefAppName -IefProxyAppName $IefProxyAppName -ExtAppDisplayName $ExtAppDisplayName
 