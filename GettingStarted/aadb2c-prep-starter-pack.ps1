param (
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$true)][Alias('x')][string]$PolicyPrefix = "",
    [Parameter(Mandatory=$false)][Alias('b')][string]$PolicyType = "SocialAndLocalAccounts",
    [Parameter(Mandatory=$false)][string]$IefAppName = "IdentityExperienceFramework",
    [Parameter(Mandatory=$false)][string]$IefProxyAppName = "ProxyIdentityExperienceFramework"    
    )

[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

$urlStarterPackBase = "https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master" #/SocialAndLocalAccounts/TrustFrameworkBase.xml

function DownloadFile ( $Url, $LocalPath ) {
    $p = $Url -split("/")
    $filename = $p[$p.Length-1]
    $LocalFile = "$LocalPath\$filename"
    Write-Host "Downloading $Url to $LocalFile"
    $webclient = New-Object System.Net.WebClient
    $webclient.DownloadFile($Url,$LocalFile)
}
# process all XML Policy files and update elements and attributes to our values
Function ProcessPolicyFiles( [string]$PolicyPath ) {
    $files = get-childitem -path $policypath -name -include *.xml | Where-Object {! $_.PSIsContainer }
    foreach( $file in $files ) {
        write-host "Modifying Policy file $file..."
        $PolicyFile = (Join-Path -Path $PolicyPath -ChildPath $file)
        [xml]$xml = Get-Content $PolicyFile
        $xml.TrustFrameworkPolicy.PolicyId = $xml.TrustFrameworkPolicy.PolicyId.Replace("B2C_1A_", $PolicyPrefix)
        $xml.TrustFrameworkPolicy.TenantId = $TenantName
        $xml.TrustFrameworkPolicy.PublicPolicyUri = $xml.TrustFrameworkPolicy.PublicPolicyUri.Replace( "yourtenant.onmicrosoft.com", $TenantName)
        $xml.TrustFrameworkPolicy.PublicPolicyUri = $xml.TrustFrameworkPolicy.PublicPolicyUri.Replace("B2C_1A_", $PolicyPrefix)
        if ( $null -ne $xml.TrustFrameworkPolicy.BasePolicy ) {
            $xml.TrustFrameworkPolicy.BasePolicy.TenantId = $TenantName
            $xml.TrustFrameworkPolicy.BasePolicy.PolicyId = $xml.TrustFrameworkPolicy.BasePolicy.PolicyId.Replace("B2C_1A_", $PolicyPrefix)
        }
        if ( $xml.TrustFrameworkPolicy.PolicyId -imatch "TrustFrameworkExtensions" ) {
            foreach( $cp in $xml.TrustFrameworkPolicy.ClaimsProviders.ClaimsProvider ) {
                if ( "Local Account SignIn" -eq $cp.DisplayName ) {
                    foreach( $tp in $cp.TechnicalProfiles ) {
                        foreach( $metadata in $tp.TechnicalProfile.Metadata ) {
                            foreach( $item in $metadata.Item ) {
                                if ( "ProxyIdentityExperienceFrameworkAppId" -eq $item.'#text' ) {
                                    $item.'#text' = $AppIdIEFProxy
                                }
                                if ( "IdentityExperienceFrameworkAppId" -eq $item.'#text' ) {
                                    $item.'#text' = $AppIdIEF
                                }
                            }
                        }
                        foreach( $ic in $tp.TechnicalProfile.InputClaims.InputClaim ) {
                            if ( "ProxyIdentityExperienceFrameworkAppId" -eq $ic.DefaultValue ) {
                                $ic.DefaultValue = $AppIdIEFProxy
                            }
                            if ( "IdentityExperienceFrameworkAppId" -eq $ic.DefaultValue ) {
                                $ic.DefaultValue = $AppIdIEF
                            }
                        }
                    }
                }
            }
        }
        $xml.Save($PolicyFile)
    }
}

<##>
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
<##>

<##>
if ( "" -eq $tenantID ) {
    write-host "Unknown Tenant"
    exit 2
}
write-host "Tenant:  `t$tenantName`nTenantID:`t$tenantId"

<##>
write-host "Getting AppID's for IdentityExperienceFramework / ProxyIdentityExperienceFramework"
$AppIdIEF = (Get-AzureADApplication -Filter "DisplayName eq '$iefAppName'").AppId
$AppIdIEFProxy = (Get-AzureADApplication -Filter "DisplayName eq '$iefProxyAppName'").AppId

if ( ! $PolicyPrefix.StartsWith("B2C_1A_") ) {
    $PolicyPrefix = "B2C_1A_$PolicyPrefix" 
}
if ( ! $PolicyPrefix.EndsWith("_") ) {
    $PolicyPrefix = "$($PolicyPrefix)_" 
}

if ( "" -eq $PolicyPath ) {
    $PolicyPath = (get-location).Path
}
DownloadFile "$urlStarterPackBase/$PolicyType/TrustFrameworkBase.xml" $PolicyPath
DownloadFile "$urlStarterPackBase/$PolicyType/TrustFrameworkExtensions.xml" $PolicyPath
DownloadFile "$urlStarterPackBase/$PolicyType/SignUpOrSignin.xml" $PolicyPath
DownloadFile "$urlStarterPackBase/$PolicyType/PasswordReset.xml" $PolicyPath
DownloadFile "$urlStarterPackBase/$PolicyType/ProfileEdit.xml" $PolicyPath
# 
ProcessPolicyFiles $PolicyPath

