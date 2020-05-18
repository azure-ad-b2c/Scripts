param (
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('x')][string]$PolicyPrefix = "",
    [Parameter(Mandatory=$false)][string]$IefAppName = "IdentityExperienceFramework",
    [Parameter(Mandatory=$false)][string]$IefProxyAppName = "ProxyIdentityExperienceFramework",    
    [Parameter(Mandatory=$false)][string]$ExtAppDisplayName = "b2c-extensions-app"     # name of add for b2c extension attributes
    )

Function UpdatePolicyId([string]$PolicyId) {
    if ( "" -ne $PolicyPrefix ) {
        $PolicyId = $PolicyId.Replace("B2C_1A_", $PolicyPrefix)
    }
    return $PolicyId
}
# process all XML Policy files and update elements and attributes to our values
Function ProcessPolicyFiles( [string]$PolicyPath ) {
    $files = get-childitem -path $policypath -name -include *.xml | Where-Object {! $_.PSIsContainer }
    foreach( $file in $files ) {
        write-host "Modifying Policy file $file..."
        $PolicyFile = (Join-Path -Path $PolicyPath -ChildPath $file)
        [xml]$xml = Get-Content $PolicyFile
        $xml.TrustFrameworkPolicy.PolicyId = UpdatePolicyId( $xml.TrustFrameworkPolicy.PolicyId )
        $xml.TrustFrameworkPolicy.PublicPolicyUri = UpdatePolicyId( $xml.TrustFrameworkPolicy.PublicPolicyUri.Replace( $xml.TrustFrameworkPolicy.TenantId, $TenantName) )
        $xml.TrustFrameworkPolicy.TenantId = $TenantName
        if ( $null -ne $xml.TrustFrameworkPolicy.BasePolicy ) {
            $xml.TrustFrameworkPolicy.BasePolicy.TenantId = $TenantName
            $xml.TrustFrameworkPolicy.BasePolicy.PolicyId = UpdatePolicyId( $xml.TrustFrameworkPolicy.BasePolicy.PolicyId )
        }
        if ( $xml.TrustFrameworkPolicy.PolicyId -imatch "TrustFrameworkExtensions" ) {
            foreach( $cp in $xml.TrustFrameworkPolicy.ClaimsProviders.ClaimsProvider ) {
                if ( "Local Account SignIn" -eq $cp.DisplayName ) {
                    foreach( $tp in $cp.TechnicalProfiles ) {
                        foreach( $metadata in $tp.TechnicalProfile.Metadata ) {
                            foreach( $item in $metadata.Item ) {
                                if ( "client_id" -eq $item.Key ) {
                                    $item.'#text' = $AppIdIEFProxy
                                }
                                if ( "IdTokenAudience" -eq $item.Key ) {
                                    $item.'#text' = $AppIdIEF
                                }
                            }
                        }
                        foreach( $ic in $tp.TechnicalProfile.InputClaims.InputClaim ) {
                            if ( "client_id" -eq $ic.ClaimTypeReferenceId ) {
                                $ic.DefaultValue = $AppIdIEFProxy
                            }
                            if ( "resource_id" -eq $ic.ClaimTypeReferenceId ) {
                                $ic.DefaultValue = $AppIdIEF
                            }
                        }
                    }
                }
                if ( "" -ne $ExtAppDisplayName -and "Azure Active Directory" -eq $cp.DisplayName ) {
                    foreach( $tp in $cp.TechnicalProfiles ) {
                        foreach( $metadata in $tp.TechnicalProfile.Metadata ) {
                            foreach( $item in $metadata.Item ) {
                                if ( "ClientId" -eq $item.Key ) {
                                    $item.'#text' = $appExt.AppId
                                }
                                if ( "ApplicationObjectId" -eq $item.Key ) {
                                    $item.'#text' = $appExt.objectId
                                }
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

if ( "" -ne $ExtAppDisplayName ) {    
    write-output "Getting AppID's for $ExtAppDisplayName"
    $appExt = Get-AzureADApplication -SearchString $ExtAppDisplayName
}

if ( "" -eq $PolicyPath ) {
    $PolicyPath = (get-location).Path
}
if ( ! $PolicyPrefix.StartsWith("B2C_1A_") ) {
    $PolicyPrefix = "B2C_1A_$PolicyPrefix" 
}
if ( ! $PolicyPrefix.EndsWith("_") ) {
    $PolicyPrefix = "$($PolicyPrefix)_" 
}
# 
ProcessPolicyFiles $PolicyPath

