function Get-AzureADB2CStarterPack(
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('b')][string]$PolicyType = "SocialAndLocalAccounts",
    [Parameter(Mandatory=$false)][Alias('f')][string]$PolicyFile = ""    
)
{
    $urlStarterPackBase = "https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master" #/SocialAndLocalAccounts/TrustFrameworkBase.xml

    function DownloadFile ( $Url, $LocalPath ) {
        $p = $Url -split("/")
        $filename = $p[$p.Length-1]
        $LocalFile = "$LocalPath/$filename"
        Write-Host "Downloading $Url to $LocalFile"
        $webclient = New-Object System.Net.WebClient
        $webclient.DownloadFile($Url,$LocalFile)
    }
    
    if ( "" -eq $PolicyPath ) {
        $PolicyPath = (get-location).Path
    }

    if ( "" -ne $PolicyFile ) {
        DownloadFile "$urlStarterPackBase/$PolicyType/$PolicyFile" $PolicyPath
    } else {
        DownloadFile "$urlStarterPackBase/$PolicyType/TrustFrameworkBase.xml" $PolicyPath
        DownloadFile "$urlStarterPackBase/$PolicyType/TrustFrameworkExtensions.xml" $PolicyPath
        DownloadFile "$urlStarterPackBase/$PolicyType/SignUpOrSignin.xml" $PolicyPath
        DownloadFile "$urlStarterPackBase/$PolicyType/PasswordReset.xml" $PolicyPath
        DownloadFile "$urlStarterPackBase/$PolicyType/ProfileEdit.xml" $PolicyPath
    }
}

function New-AzureADB2CPolicyProject
(
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('x')][string]$PolicyPrefix = "",
    [Parameter(Mandatory=$false)][boolean]$AzureCli = $False         # if to force Azure CLI on Windows
    )
{
    Get-AzureADB2CStarterPack -PolicyPath $PolicyPath
    Set-AzureADB2CPolicyDetails -TenantName $TenantName -PolicyPath $PolicyPath -PolicyPrefix $PolicyPrefix
    Set-AzureADB2CCustomAttributeApp -PolicyPath $PolicyPath
    Set-AzureADB2CAppInsights -PolicyPath $PolicyPath
    Set-AzureADB2CCustomizeUX -PolicyPath $PolicyPath
}

function Set-AzureADB2CPolicyDetails
(
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('f')][string]$PolicyFile = "",
    [Parameter(Mandatory=$false)][Alias('x')][string]$PolicyPrefix = "",
    [Parameter(Mandatory=$false)][string]$IefAppName = "",
    [Parameter(Mandatory=$false)][string]$IefProxyAppName = "",    
    [Parameter(Mandatory=$false)][string]$ExtAppDisplayName = "b2c-extensions-app",     # name of add for b2c extension attributes
    [Parameter(Mandatory=$false)][switch]$Clean = $False,            # if to "clean" the policies and revert to "yourtenant.onmicrosoft.com" etc
    [Parameter(Mandatory=$false)][boolean]$AzureCli = $False         # if to force Azure CLI on Windows
    )
{

if ( $True -eq $Clean ) {
    $TenantName = "yourtenant.onmicrosoft.com"
    $IefAppName = "IdentityExperienceFramework"
    $IefProxyAppName = "ProxyIdentityExperienceFramework"
    write-output "Making Policies generic for sharing"
} else {
    if ( "" -eq $TenantName ) { $TenantName = $global:TenantName }
    if ( "" -eq $IefAppName ) { $IefAppName = $global:b2cAppSettings.IefAppName}
    if ( "" -eq $IefAppName ) { $IefAppName = "IdentityExperienceFramework"}
    if ( "" -eq $IefProxyAppName ) { $IefProxyAppName = $global:b2cAppSettings.IefProxyAppName}
    if ( "" -eq $IefProxyAppName ) { $IefProxyAppName = "ProxyIdentityExperienceFramework"}
}

$isWinOS = ($env:PATH -imatch "/usr/bin" )                 # Mac/Linux
if ( $isWinOS ) { $AzureCLI = $True}

Function UpdatePolicyId([string]$PolicyId) {
    if ( "" -ne $PolicyPrefix ) {
        $PolicyId = $PolicyId.Replace("B2C_1A_", $PolicyPrefix)
    }
    return $PolicyId
}

Function ProcessPolicyFile( [string]$PolicyPath, [string]$file ) {
        write-host "Modifying Policy file $file..."
        $PolicyFileName = (Join-Path -Path $PolicyPath -ChildPath $file)
        [xml]$xml = Get-Content $PolicyFileName
        $xml.TrustFrameworkPolicy.PolicyId = UpdatePolicyId( $xml.TrustFrameworkPolicy.PolicyId )
        $xml.TrustFrameworkPolicy.PublicPolicyUri = UpdatePolicyId( $xml.TrustFrameworkPolicy.PublicPolicyUri.Replace( $xml.TrustFrameworkPolicy.TenantId, $TenantName) )
        $xml.TrustFrameworkPolicy.TenantId = $TenantName
        if ( $null -ne $xml.TrustFrameworkPolicy.BasePolicy ) {
            $xml.TrustFrameworkPolicy.BasePolicy.TenantId = $TenantName
            $xml.TrustFrameworkPolicy.BasePolicy.PolicyId = UpdatePolicyId( $xml.TrustFrameworkPolicy.BasePolicy.PolicyId )
        }
        if ( $xml.TrustFrameworkPolicy.PolicyId -imatch "TrustFrameworkExtensions" ) {
            foreach( $cp in $xml.TrustFrameworkPolicy.ClaimsProviders.ClaimsProvider ) {
                $cp.DisplayName
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
                } else {
                    if ( $True -eq $Clean ) {
                        foreach( $tp in $cp.TechnicalProfiles ) {
                            foreach( $metadata in $tp.TechnicalProfile.Metadata ) {
                                foreach( $item in $metadata.Item ) {
                                    if ( "client_id" -eq $item.Key ) {
                                        $item.'#text' = "...add your client_id here..."
                                    }
                                }
                            }
                        }
                    }
                }

                if ( "" -ne $ExtAppDisplayName ) {
                    foreach( $tp in $cp.TechnicalProfiles ) {
                        if ( "AAD-Common" -eq $tp.TechnicalProfile.Id[0] -or "AAD-Common" -eq $tp.TechnicalProfile.Id) {
                            foreach( $metadata in $tp.TechnicalProfile.Metadata ) {
                                foreach( $item in $metadata.Item ) {
                                    if ( "ClientId" -eq $item.Key ) {
                                        $item.'#text' = $appExtAppId
                                    }
                                    if ( "ApplicationObjectId" -eq $item.Key ) {
                                        $item.'#text' = $appExtObjectId
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        if ( $True -eq $Clean ) {
            foreach( $rp in $xml.TrustFrameworkPolicy.RelyingParty ) {
                if ( $null -ne $rp.UserJourneyBehaviors -and $null -ne $rp.UserJourneyBehaviors.JourneyInsights ) {
                    $rp.UserJourneyBehaviors.JourneyInsights.InstrumentationKey = "...add your key here..."
                }
            }
        }

        $xml.Save($PolicyFileName)
}

# process all XML Policy files and update elements and attributes to our values
Function ProcessPolicyFiles( [string]$PolicyPath ) {
    $files = get-childitem -path $policypath -name -include *.xml | Where-Object {! $_.PSIsContainer }
    foreach( $file in $files ) {
        ProcessPolicyFile $PolicyPath $file
    }
}

<##>
$tenantID = ""
$appExtAppId = ""
$appExtObjectId = ""
if ( $True -eq $Clean ) {
    $AppIdIEF = "IdentityExperienceFrameworkAppId"
    $AppIdIEFProxy = "ProxyIdentityExperienceFrameworkAppId"
    $appExtAppId = "b2c-extension-app AppId"
    $appExtObjectId = "b2c-extension-app objectId"
} else {
    $resp = Invoke-RestMethod -Uri "https://login.windows.net/$TenantName/v2.0/.well-known/openid-configuration"
    $tenantID = $resp.authorization_endpoint.Split("/")[3]    
    <##>
    if ( "" -eq $tenantID ) {
        write-host "Unknown Tenant"
        return
    }
    write-host "Tenant:  `t$tenantName`nTenantID:`t$tenantId"

    <##>
    write-host "Getting AppID's for $IefAppName / $IefProxyAppName"
    if ( $True -eq $AzureCli ) {
        $AppIdIEF = (az ad app list --display-name $iefAppName | ConvertFrom-json).AppId
        $AppIdIEFProxy = (az ad app list --display-name $iefProxyAppName | ConvertFrom-json).AppId
        if ( "" -ne $ExtAppDisplayName ) {    
            write-output "Getting AppID's for $ExtAppDisplayName"
            $appExt = (az ad app list --display-name $ExtAppDisplayName | ConvertFrom-json)
            $appExtAppId = $appExt.AppId
            $appExtObjectId = $appExt.objectId
       }
    } else {
        $AppIdIEF = (Get-AzureADApplication -Filter "DisplayName eq '$iefAppName'").AppId
        $AppIdIEFProxy = (Get-AzureADApplication -Filter "DisplayName eq '$iefProxyAppName'").AppId  
        if ( "" -ne $ExtAppDisplayName ) {    
            write-output "Getting AppID's for $ExtAppDisplayName"
            $appExt = Get-AzureADApplication -SearchString $ExtAppDisplayName
            write-output $appExt.AppID
            $appExtAppId = $appExt.AppId
            $appExtObjectId = $appExt.objectId
        }
    }
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

if ( "" -ne $PolicyFile ) {
    ProcessPolicyFile $PolicyPath $PolicyFile
} else {
    ProcessPolicyFiles $PolicyPath
}


}

function Get-AzureADB2CPolicyId
(
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyId = "",
    [Parameter(Mandatory=$false)][Alias('f')][string]$PolicyFile = "",
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('a')][string]$AppID = "",
    [Parameter(Mandatory=$false)][Alias('k')][string]$AppKey = "",
    [Parameter(Mandatory=$false)][boolean]$AzureCli = $False         # if to force Azure CLI on Windows
    )
{
    $oauth = $null
    if ( "" -eq $AppID ) { $AppID = $env:B2CAppId }
    if ( "" -eq $AppKey ) { $AppKey = $env:B2CAppKey }
    if ( "" -eq $TenantName ) { $TenantName = $global:TenantName }
    $isWinOS = ($env:PATH -imatch "/usr/bin" )                 # Mac/Linux    
    if ( $isWinOS ) { $AzureCLI = $True}    

    # either try and use the tenant name passed or grab the tenant from current session
    <##>
    $tenantID = ""
    $resp = Invoke-RestMethod -Uri "https://login.windows.net/$TenantName/v2.0/.well-known/openid-configuration"
    $tenantID = $resp.authorization_endpoint.Split("/")[3]    
    <##>
    
    <##>
    if ( "" -eq $tenantID ) {
        write-host "Unknown Tenant"
        return
    }
    #write-host "Tenant:  `t$tenantName`nTenantID:`t$tenantId"
    
    # check the B2C Graph App passed
    if ( $True -eq $AzureCli ) {
        $app = (az ad app show --id $AppID | ConvertFrom-json)
    } else {
        $app = Get-AzureADApplication -Filter "AppID eq '$AppID'"
    }
    if ( $null -eq $app ) {
        write-host "App not found in B2C tenant: $AppID"
        return
    } else {
        #write-host "`Authenticating as App $($app.DisplayName), AppID $AppID"
    }
       
    # https://docs.microsoft.com/en-us/azure/active-directory/users-groups-roles/directory-assign-admin-roles#b2c-user-flow-administrator
    # get an access token for the B2C Graph App
    $oauthBody  = @{grant_type="client_credentials";resource="https://graph.microsoft.com/";client_id=$AppID;client_secret=$AppKey;scope="Policy.ReadWrite.TrustFramework"}
    $oauth      = Invoke-RestMethod -Method Post -Uri "https://login.microsoft.com/$tenantName/oauth2/token?api-version=1.0" -Body $oauthBody
    
    write-host "Getting policy $PolicyId..."
    $url = "https://graph.microsoft.com/beta/trustFramework/policies/$PolicyId/`$value"
    $resp = Invoke-RestMethod -Method GET -Uri $url -ContentType "application/xml" -Headers @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"} 
    if ( "" -eq $PolicyFile ) {
        write-host $resp.OuterXml
    } else {
        Set-Content -Path $PolicyFile -Value $resp.OuterXml 
    }

}

function List-AzureADB2CPolicyIds
(
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyId = "",
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('a')][string]$AppID = "",
    [Parameter(Mandatory=$false)][Alias('k')][string]$AppKey = "",
    [Parameter(Mandatory=$false)][boolean]$AzureCli = $False         # if to force Azure CLI on Windows
    )
{
    $oauth = $null
    if ( "" -eq $AppID ) { $AppID = $env:B2CAppId }
    if ( "" -eq $AppKey ) { $AppKey = $env:B2CAppKey }
    if ( "" -eq $TenantName ) { $TenantName = $global:TenantName }
    $isWinOS = ($env:PATH -imatch "/usr/bin" )                 # Mac/Linux    
    if ( $isWinOS ) { $AzureCLI = $True}    

    # either try and use the tenant name passed or grab the tenant from current session
    <##>
    $tenantID = ""
    $resp = Invoke-RestMethod -Uri "https://login.windows.net/$TenantName/v2.0/.well-known/openid-configuration"
    $tenantID = $resp.authorization_endpoint.Split("/")[3]    
    <##>
    
    <##>
    if ( "" -eq $tenantID ) {
        write-host "Unknown Tenant"
        return
    }
    #write-host "Tenant:  `t$tenantName`nTenantID:`t$tenantId"
    
    # check the B2C Graph App passed
    if ( $True -eq $AzureCli ) {
        $app = (az ad app show --id $AppID | ConvertFrom-json)
    } else {
        $app = Get-AzureADApplication -Filter "AppID eq '$AppID'"
    }
    if ( $null -eq $app ) {
        write-host "App not found in B2C tenant: $AppID"
        return
    } else {
        #write-host "`Authenticating as App $($app.DisplayName), AppID $AppID"
    }
       
    # https://docs.microsoft.com/en-us/azure/active-directory/users-groups-roles/directory-assign-admin-roles#b2c-user-flow-administrator
    # get an access token for the B2C Graph App
    $oauthBody  = @{grant_type="client_credentials";resource="https://graph.microsoft.com/";client_id=$AppID;client_secret=$AppKey;scope="Policy.ReadWrite.TrustFramework"}
    $oauth      = Invoke-RestMethod -Method Post -Uri "https://login.microsoft.com/$tenantName/oauth2/token?api-version=1.0" -Body $oauthBody
    
    $url = "https://graph.microsoft.com/beta/trustFramework/policies"
    $resp = Invoke-RestMethod -Method GET -Uri $url -ContentType "application/xml" -Headers @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"} 
    $resp.value | ConvertTo-json

}

function Push-AzureADB2CPolicyToTenant
(
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('f')][string]$PolicyFile = "",
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('a')][string]$AppID = "",
    [Parameter(Mandatory=$false)][Alias('k')][string]$AppKey = "",
    [Parameter(Mandatory=$false)][boolean]$AzureCli = $False         # if to force Azure CLI on Windows
    )
{
    
    $oauth = $null
    if ( "" -eq $AppID ) { $AppID = $env:B2CAppId }
    if ( "" -eq $AppKey ) { $AppKey = $env:B2CAppKey }
    if ( "" -eq $TenantName ) { $TenantName = $global:TenantName }
    $isWinOS = ($env:PATH -imatch "/usr/bin" )                 # Mac/Linux    
    if ( $isWinOS ) { $AzureCLI = $True}    

    # enumerate all XML files in the specified folders and create a array of objects with info we need
    Function EnumPoliciesFromPath( [string]$PolicyPath ) {
        $files = get-childitem -path $policypath -name -include *.xml | Where-Object {! $_.PSIsContainer }
        $arr = @()
        foreach( $file in $files ) {
            #write-output "Reading Policy XML file $file..."
            $PolicyFile = (Join-Path -Path $PolicyPath -ChildPath $file)
            $PolicyData = Get-Content $PolicyFile
            [xml]$xml = $PolicyData
            if ($null -ne $xml.TrustFrameworkPolicy) {
                $policy = New-Object System.Object
                $policy | Add-Member -type NoteProperty -name "PolicyId" -Value $xml.TrustFrameworkPolicy.PolicyId
                $policy | Add-Member -type NoteProperty -name "BasePolicyId" -Value $xml.TrustFrameworkPolicy.BasePolicy.PolicyId
                $policy | Add-Member -type NoteProperty -name "Uploaded" -Value $false
                $policy | Add-Member -type NoteProperty -name "FilePath" -Value $PolicyFile
                $policy | Add-Member -type NoteProperty -name "xml" -Value $xml
                $policy | Add-Member -type NoteProperty -name "PolicyData" -Value $PolicyData
                $arr += $policy
            }
        }
        return $arr
    }
    
    # process each Policy object in the array. For each that has a BasePolicyId, follow that dependency link
    # first call has to be with BasePolicyId null (base/root policy) for this to work
    Function ProcessPolicies( $arrP, $BasePolicyId ) {
        foreach( $p in $arrP ) {
            if ( $p.xml.TrustFrameworkPolicy.TenantId -ne $TenantName ) {
                write-output "$($p.PolicyId) has wrong tenant configured $($p.xml.TrustFrameworkPolicy.TenantId) - skipped"
            } else {
                if ( $BasePolicyId -eq $p.BasePolicyId -and $p.Uploaded -eq $false ) {
                    # upload this one
                    UploadPolicy $p.PolicyId $p.PolicyData
                    $p.Uploaded = $true
                    # process all policies that has a ref to this one
                    ProcessPolicies $arrP $p.PolicyId
                }
            }
        }
    }
    
    # invoke the Graph REST API to upload the Policy
    Function UploadPolicy( [string]$PolicyId, [string]$PolicyData) {
        # https://docs.microsoft.com/en-us/graph/api/trustframework-put-trustframeworkpolicy?view=graph-rest-beta
        # upload the Custom Policy
        write-host "Uploading policy $PolicyId..."
        $url = "https://graph.microsoft.com/beta/trustFramework/policies/$PolicyId/`$value"
        $resp = Invoke-RestMethod -Method PUT -Uri $url -ContentType "application/xml" -Headers @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"} -Body $PolicyData
        write-host $resp.TrustFrameworkPolicy.PublicPolicyUri
    }
    
    # either try and use the tenant name passed or grab the tenant from current session
    <##>
    $tenantID = ""
    $resp = Invoke-RestMethod -Uri "https://login.windows.net/$TenantName/v2.0/.well-known/openid-configuration"
    $tenantID = $resp.authorization_endpoint.Split("/")[3]    
    <##>
    
    <##>
    if ( "" -eq $tenantID ) {
        write-host "Unknown Tenant"
        return
    }
    write-host "Tenant:  `t$tenantName`nTenantID:`t$tenantId"
    
    # check the B2C Graph App passed
    if ( $True -eq $AzureCli ) {
        $app = (az ad app show --id $AppID | ConvertFrom-json)
    } else {
        $app = Get-AzureADApplication -Filter "AppID eq '$AppID'"
    }
    if ( $null -eq $app ) {
        write-host "App not found in B2C tenant: $AppID"
        return
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
        # upload a single file
        $PolicyData = Get-Content $PolicyFile # 
        [xml]$xml = $PolicyData
        UploadPolicy $xml.TrustFrameworkPolicy.PolicyId $PolicyData
    } else {
        # load the XML Policy files
        $arr = EnumPoliciesFromPath $PolicyPath
        # upload policies - start with those who have no BasePolicyId dependency (null)
        ProcessPolicies $arr $null     
        # check what hasn't been uploaded
        foreach( $p in $arr ) {
            if ( $p.Uploaded -eq $false ) {
                write-output "$($p.PolicyId) has a refence to $($p.BasePolicyId) which doesn't exists in the folder - not uploaded"
            }
        }
    }
        
}

function Set-AzureADB2CCustomAttributeApp
(
        [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",    
        [Parameter(Mandatory=$false)][Alias('c')][string]$client_id = "",    # client_id/AppId of the app handeling custom attributes
        [Parameter(Mandatory=$false)][Alias('a')][string]$objectId = "",     # objectId of the same app
        [Parameter(Mandatory=$false)][Alias('n')][string]$AppDisplayName = "",     # objectId of the same app
        [Parameter(Mandatory=$false)][Alias('f')][string]$PolicyFile = "TrustFrameworkExtensions.xml",     # if the Extensions file has a different name
        [Parameter(Mandatory=$false)][boolean]$AzureCli = $False         # if to force Azure CLI on Windows
)
{
    
    $isWinOS = ($env:PATH -imatch "/usr/bin" )                 # Mac/Linux   
    if ( $isWinOS ) { $AzureCLI = $True}           

    if ( "" -eq $PolicyPath ) {
        $PolicyPath = (get-location).Path
    }
        
    [xml]$ext =Get-Content -Path "$PolicyPath/$PolicyFile" -Raw
    
    $tpId = "AAD-Common"
    $claimsProviderXml=@"
    <ClaimsProvider>
      <DisplayName>Azure Active Directory</DisplayName>
      <TechnicalProfiles>
        <TechnicalProfile Id="AAD-Common">
          <Metadata>
            <!--Insert b2c-extensions-app application ID here, for example: 11111111-1111-1111-1111-111111111111-->  
            <Item Key="ClientId">{client_id}</Item>
            <!--Insert b2c-extensions-app application ObjectId here, for example: 22222222-2222-2222-2222-222222222222-->
            <Item Key="ApplicationObjectId">{objectId}</Item>
          </Metadata>
        </TechnicalProfile>
      </TechnicalProfiles> 
    </ClaimsProvider>
"@
    
    if ( $ext.TrustFrameworkPolicy.ClaimsProviders.InnerXml -imatch $tpId ) {
      write-output "TechnicalProfileId $tpId already exists in policy"
      return
    }
    
    # if no client_id given, use the standard b2c-extensions-app
    if ( "" -eq $client_id ) {
        if ( "" -eq $AppDisplayName ) { $AppDisplayName = "b2c-extensions-app"}
        write-output "Using $AppDisplayName"
        if ( $True -eq $AzureCli ) {
          $appExt = (az ad app list --display-name $AppDisplayName | ConvertFrom-json)
        } else {
          $appExt = Get-AzureADApplication -SearchString $AppDisplayName
        }
        $client_id = $appExt.AppId   
        $objectId = $appExt.objectId   
    }
    write-output "Adding TechnicalProfileId $tpId"
    
    $claimsProviderXml = $claimsProviderXml.Replace("{client_id}", $client_id)
    $claimsProviderXml = $claimsProviderXml.Replace("{objectId}", $objectId)
    
    $ext.TrustFrameworkPolicy.ClaimsProviders.innerXml = $ext.TrustFrameworkPolicy.ClaimsProviders.innerXml + $claimsProviderXml
    
    $ext.Save("$PolicyPath/TrustFrameworkExtensions.xml")
    
}

function Set-AzureADB2CCustomizeUX
(
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",    
    [Parameter(Mandatory=$false)][Alias('r')][string]$RelyingPartyFileName = "SignUpOrSignin.xml",
    [Parameter(Mandatory=$false)][Alias('b')][string]$BasePolicyFileName = "TrustFrameworkBase.xml",
    [Parameter(Mandatory=$false)][Alias('e')][string]$ExtPolicyFileName = "TrustFrameworkExtensions.xml",
    [Parameter(Mandatory=$false)][Alias('d')][boolean]$DownloadHtmlTemplates = $false,    
    [Parameter(Mandatory=$false)][Alias('h')][string]$HtmlFolderName = "html",    
    [Parameter(Mandatory=$false)][Alias('u')][string]$urlBaseUx = ""
    )
{
    
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    
    function DownloadFile ( $Url, $LocalPath ) {
        $p = $Url -split("/")
        $filename = $p[$p.Length-1]
        $LocalFile = "$LocalPath\$filename"
        Write-Host "Downloading $Url to $LocalFile"
        $webclient = New-Object System.Net.WebClient
        $webclient.DownloadFile($Url,$LocalFile)
    }
        
    if ( "" -eq $PolicyPath ) {
        $PolicyPath = (get-location).Path
    }
        
    [xml]$base =Get-Content -Path "$PolicyPath\$BasePolicyFileName" -Raw
    [xml]$ext =Get-Content -Path "$PolicyPath\$ExtPolicyFileName" -Raw
    
    $tenantShortName = $base.TrustFrameworkPolicy.TenantId.Split(".")[0]
    $cdefs = $base.TrustFrameworkPolicy.BuildingBlocks.ContentDefinitions.Clone()
    
    if ( $true -eq $DownloadHtmlTemplates) {    
        $ret = New-Item -Path $PolicyPath -Name "$HtmlFolderName" -ItemType "directory" -ErrorAction SilentlyContinue
    }
    <##>
    foreach( $contDef in $cdefs.ContentDefinition ) {    
        switch( $contDef.DataUri ) {        
            "urn:com:microsoft:aad:b2c:elements:globalexception:1.0.0" { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:globalexception:1.2.0" } 
            "urn:com:microsoft:aad:b2c:elements:globalexception:1.1.0" { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:globalexception:1.2.0" }
            "urn:com:microsoft:aad:b2c:elements:idpselection:1.0.0"    { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:providerselection:1.2.0" }
            "urn:com:microsoft:aad:b2c:elements:multifactor:1.0.0"     { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:multifactor:1.2.1" }
            "urn:com:microsoft:aad:b2c:elements:multifactor:1.1.0"     { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:multifactor:1.2.1" }
    
            "urn:com:microsoft:aad:b2c:elements:unifiedssd:1.0.0"    { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:unifiedssd:2.1.0" } 
            "urn:com:microsoft:aad:b2c:elements:unifiedssp:1.0.0"    { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:unifiedssp:2.1.0" } 
    
            "urn:com:microsoft:aad:b2c:elements:selfasserted:1.0.0"    { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:selfasserted:2.1.0" } 
            "urn:com:microsoft:aad:b2c:elements:selfasserted:1.1.0"    { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:selfasserted:2.1.0" }
        }  
        if ( $true -eq $DownloadHtmlTemplates) {
            $url = "https://$tenantShortName.b2clogin.com/static" + $contDef.LoadUri.Replace("~", "")
            DownloadFile $url "$PolicyPath\$HtmlFolderName"
        }
        if ( "" -ne $urlBaseUx ) {
            $p = $contDef.LoadUri -split("/")
            $filename = $p[$p.Length-1]
            $contDef.LoadUri = "$urlBaseUx/$filename"
        }
    }
    
    if ( $null -ne $ext.TrustFrameworkPolicy.BuildingBlocks.ContentDefinitions ) {
        $ext.TrustFrameworkPolicy.BuildingBlocks.RemoveChild( $ext.TrustFrameworkPolicy.BuildingBlocks.ContentDefinitions )
    }
    <##>
    $ext.TrustFrameworkPolicy.InnerXml = $ext.TrustFrameworkPolicy.InnerXml.Replace("</BuildingBlocks>", "<ContentDefinitions>" + $cdefs.InnerXml + "</ContentDefinitions></BuildingBlocks>")
    $ext.Save("$PolicyPath\$ExtPolicyFileName")
    
    <##>
    if ( "" -ne $RelyingPartyFileName ) {
        [xml]$rp =Get-Content -Path "$PolicyPath\$RelyingPartyFileName" -Raw
        # don't have UserJourneyBehaviors - add it directly after DefaultUserJourney element
        if ( $null -eq $rp.TrustFrameworkPolicy.RelyingParty.UserJourneyBehaviors ) {
            $rp.TrustFrameworkPolicy.RelyingParty.InnerXml = $rp.TrustFrameworkPolicy.RelyingParty.InnerXml.Replace("<TechnicalProfile", "<UserJourneyBehaviors><ScriptExecution>Allow</ScriptExecution></UserJourneyBehaviors><TechnicalProfile")
        } else {
            $rp.TrustFrameworkPolicy.RelyingParty.InnerXml = $rp.TrustFrameworkPolicy.RelyingParty.InnerXml.Replace("</UserJourneyBehaviors>", "<ScriptExecution>Allow</ScriptExecution></UserJourneyBehaviors>")
        }
        $rp.Save("$PolicyPath\$RelyingPartyFileName")
    }
    <##>    
}

function Test-AzureADB2CPolicy
(
    [Parameter(Mandatory=$true)][Alias('p')][string]$PolicyFile,
    [Parameter(Mandatory=$true)][Alias('n')][string]$WebAppName = "",
    [Parameter(Mandatory=$false)][Alias('r')][string]$redirect_uri = "https://jwt.ms",
    [Parameter(Mandatory=$false)][Alias('s')][string]$scopes = "",
    [Parameter(Mandatory=$false)][Alias('t')][string]$response_type = "id_token",
    [Parameter(Mandatory=$false)][boolean]$AzureCli = $False         # if to force Azure CLI on Windows
    )
{
    
    if (!(Test-Path $PolicyFile -PathType leaf)) {
        write-error "File does not exists: $PolicyFile"
        return
    }
    $isWinOS = ($env:PATH -imatch "/usr/bin" )                 # Mac/Linux    
    if ( $isWinOS ) { $AzureCLI = $True}

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
    if ( $True -eq $AzureCli ) {
        $app = (az ad app list --display-name $WebAppName | ConvertFrom-json)
    } else {
        $app = Get-AzureADApplication -SearchString $WebAppName -ErrorAction SilentlyContinue
    }
    
    if ( $null -eq $app ) {
        write-error "App isn't registered: $WebAppName"
        return
    }
    if ( $app.Count -gt 1 ) {
        $app = ($app | where {$_.DisplayName -eq $WebAppName})
    }
    if ( $app.Count -gt 1 ) {
        write-error "App name isn't unique: $WebAppName"
        return
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
        # if extra scopes passed on cmdline, then we will also ask for an access_token
        if ( "" -ne $scopes ) {
            $scope = "openid offline_access $scopes"
            $response_type = "$response_type token"
        }
        $qparams = "client_id={0}&nonce={1}&redirect_uri={2}&scope={3}&response_type={4}&prompt=login&disable_cache=true" `
                    -f $app.AppId.ToString(), (New-Guid).Guid, $redirect_uri, $scope, $response_type
        # Q&D urlencode
        $qparams = $qparams.Replace(":","%3A").Replace("/","%2F").Replace(" ", "%20")
    
        $url = "https://{0}.b2clogin.com/{1}/{2}/oauth2/v2.0/authorize?{3}" -f $tenantName.Split(".")[0], $tenantName, $PolicyId, $qparams
    }
    
    write-host "Starting Browser`n$url"
    
    if ( $isWinOS ) {
        $ret = [System.Diagnostics.Process]::Start("/usr/bin/open","$url")
    } else {
        $ret = [System.Diagnostics.Process]::Start($pgm,"$params $url")
    }
        
}

function Delete-AzureADB2CPolicyFromTenant
(
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('f')][string]$PolicyFile = "",
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('a')][string]$AppID = "",
    [Parameter(Mandatory=$false)][Alias('k')][string]$AppKey = "",
    [Parameter(Mandatory=$false)][boolean]$AzureCli = $False         # if to force Azure CLI on Windows
    )
{    
    $oauth = $null
    if ( "" -eq $AppID ) { $AppID = $env:B2CAppId }
    if ( "" -eq $AppKey ) { $AppKey = $env:B2CAppKey }
    if ( "" -eq $TenantName ) { $TenantName = $global:TenantName }
    $isWinOS = ($env:PATH -imatch "/usr/bin" )                 # Mac/Linux  
    if ( $isWinOS ) { $AzureCLI = $True}      
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
        return
    }
    write-host "Tenant:  `t$tenantName`nTenantID:`t$tenantId"
    
    # check the B2C Graph App passed
    if ( $True -eq $AzureCli ) {
        $app = (az ad app show --id $AppID | ConvertFrom-json)
    } else {
        $app = Get-AzureADApplication -Filter "AppID eq '$AppID'"
    }
    if ( $null -eq $app ) {
        write-host "App not found in B2C tenant: $AppID"
        return
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
    
}

function Set-AzureADB2CAppInsights
(
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",              # either a path and all xml files will be processed
    [Parameter(Mandatory=$false)][Alias('f')][string]$PolicyFile = "",              # or a single file
    [Parameter(Mandatory=$false)][Alias('k')][string]$InstrumentationKey = ""       # AppInsighs key
    )
{
    
    if ( "" -eq $InstrumentationKey) { $InstrumentationKey = $global:InstrumentationKey }
    
    if ( 36 -ne $InstrumentationKey.Length ) {
        write-host "InstrumentationKey needs to be a guid"
        return 
    }
    
    $JourneyInsights = @"
    <JourneyInsights TelemetryEngine="ApplicationInsights" InstrumentationKey="{InstrumentationKey}" 
    DeveloperMode="true" ClientEnabled="true" ServerEnabled="true" TelemetryVersion="1.0.0" />
"@
    
    # enumerate all XML files in the specified folders and create a array of objects with info we need
    Function EnumPoliciesFromPath( [string]$PolicyPath ) {
        $files = get-childitem -path $policypath -name -include *.xml | Where-Object {! $_.PSIsContainer }
        foreach( $file in $files ) {
            #write-output "Reading Policy XML file $file..."
            $File = (Join-Path -Path $PolicyPath -ChildPath $file)
            ProcessPolicyFile $File
        }
    }
    
    Function ProcessPolicyFile( $File ) {
        $PolicyData = Get-Content $File
        [xml]$xml = $PolicyData
        if ( $null -ne $xml.TrustFrameworkPolicy.RelyingParty ) {
            AddAppInsightToPolicy $File $xml
        }
    }
    # process each Policy object in the array. For each that has a BasePolicyId, follow that dependency link
    # first call has to be with BasePolicyId null (base/root policy) for this to work
    Function AddAppInsightToPolicy( $PolicyFile, $xml ) {
        $changed = $false
        foreach( $rp in $xml.TrustFrameworkPolicy.RelyingParty ) {
            # already have AppInsight - just upd key
            if ( $null -ne $rp.UserJourneyBehaviors -and $null -ne $rp.UserJourneyBehaviors.JourneyInsights ) {
                $rp.UserJourneyBehaviors.JourneyInsights.InstrumentationKey = $InstrumentationKey
                $changed = $true
            }
            # might have UserJourneyBehaviors for javascript - add JourneyInsights
            if ( $null -ne $rp.UserJourneyBehaviors -and $null -eq $rp.UserJourneyBehaviors.JourneyInsights ) {
                $rp.InnerXml = $rp.InnerXml.Replace("</UserJourneyBehaviors>", "$JourneyInsights</UserJourneyBehaviors>")
                $changed = $true
            }
            # don't have UserJourneyBehaviors - add it directly after DefaultUserJourney element
            if ( $null -eq $rp.UserJourneyBehaviors ) {
                $idx = $rp.InnerXml.IndexOf("/>")
                $rp.InnerXml = $rp.InnerXml.Substring(0,$idx+2) + "<UserJourneyBehaviors>$JourneyInsights</UserJourneyBehaviors>" + $rp.InnerXml.Substring($idx+2)
                $changed = $true
            }
        }
        if ( $null -eq $xml.TrustFrameworkPolicy.UserJourneyRecorderEndpoint ) {
            $idx = $xml.InnerXml.IndexOf(">")
            $idx += $xml.InnerXml.Substring($idx+1).IndexOf(">")
            $xml.InnerXml = $xml.InnerXml.Substring(0,$idx+1) + " DeploymentMode=`"Development`" UserJourneyRecorderEndpoint=`"urn:journeyrecorder:applicationinsights`"" + $xml.InnerXml.Substring($idx+1)
            $changed = $true
        }
        if ( $changed ) {
            $xml.TrustFrameworkPolicy.InnerXml = $xml.TrustFrameworkPolicy.InnerXml.Replace( "xmlns=`"http://schemas.microsoft.com/online/cpim/schemas/2013/06`"", "") 
            write-output "Adding AppInsights InstrumentationKey $InstrumentationKey to $($xml.TrustFrameworkPolicy.PolicyId)"
            $xml.Save($File)        
        }
    }
    
    $JourneyInsights = $JourneyInsights.Replace("{InstrumentationKey}", $InstrumentationKey)
    <##>
    if ( "" -eq $PolicyPath ) {
        $PolicyPath = (get-location).Path
    }
    
    if ( "" -ne $PolicyFile ) {
        # process a single file
        ProcessPolicyFile (Resolve-Path $PolicyFile).Path
    } else {
        # process all policies that has a RelyingParty
        EnumPoliciesFromPath $PolicyPath
    }
        
}

function Connect-AzureADB2CEnv
(
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('c')][string]$ConfigPath = "",
    [Parameter(Mandatory=$false)][boolean]$AzureClI = $False    
)
{
    if ( "" -ne $ConfigPath ) {
        $global:b2cAppSettings =(Get-Content -Path $ConfigPath | ConvertFrom-json)
        $Tenant = $global:b2cAppSettings.TenantName
        $TenantName = $global:b2cAppSettings.TenantName
    }
    if ( "" -eq $TenantName ) {
        write-error "Unknown Tenant. Either use the -TenantName or the -ConfigPath parameter"
        return
    }

    if ( !($TenantName -imatch ".onmicrosoft.com") ) {
        $TenantName = $TenantName + ".onmicrosoft.com"
    }
    $isWinOS = ($env:PATH -imatch "/usr/bin" )                 # Mac/Linux
    if ( $isWinOS ) { $AzureCLI = $True}

    if ( $TenantName.Length -eq 36 -and $TenantName.Contains("-") -eq $true)  {
        $TenantID = $TenantName
    } else {
        $url = "https://login.windows.net/$TenantName/v2.0/.well-known/openid-configuration"
        $resp = Invoke-RestMethod -Uri $url
        $TenantID = $resp.authorization_endpoint.Split("/")[3]    
        write-output $TenantID
    }
    
    $startTime = Get-Date
    
    if ( $True -eq $AzureCli ) {
        $ctx = (az login --tenant $TenantID --allow-no-subscriptions | ConvertFrom-json)
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
    
    $host.ui.RawUI.WindowTitle = "PS AADB2C $type - $user - $Tenant"
    
    $global:tenantName = $tenantName
    $global:tenantID = $tenantID

    if ( "" -ne $ConfigPath) {
        $global:PolicyPath = $PolicyPath
        $global:ConfigPath = $ConfigPath
        $global:InstrumentationKey=$b2cAppSettings.InstrumentationKey
        
        $env:B2CAppId=$b2cAppSettings.ClientCredentials.client_id
        $env:B2CAppKey=$b2cAppSettings.ClientCredentials.client_secret
        $global:B2CAppId=$b2cAppSettings.ClientCredentials.client_id
        $global:B2CAppKey=$b2cAppSettings.ClientCredentials.client_secret
                   
        write-output "Config File    :`t$ConfigPath"
        write-output "B2C Tenant     :`t$tenantID, $tenantName"
        write-output "B2C Client Cred:`t$($env:B2CAppId), $($app.DisplayName)"
    }
    
}

function Read-AzureADB2CConfig
(
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('n')][string]$PolicyPrefix = "",  
    [Parameter(Mandatory=$false)][Alias('k')][boolean]$KeepPolicyIds = $False,  
    [Parameter(Mandatory=$true)][Alias('c')][string]$ConfigPath = "", 
    [Parameter(Mandatory=$false)][boolean]$AzureCli = $False         # if to force Azure CLI on Windows
    )
{
    
    if ( !(Test-Path $ConfigPath -PathType Leaf) ) {
        write-error "Config file not found $ConfigPath"
        return
    }
    $isWinOS = ($env:PATH -imatch "/usr/bin" )                 # Mac/Linux
    if ( $isWinOS ) { $AzureCLI = $True}

    if ( "" -eq $PolicyPath ) {
        $PolicyPath = (get-location).Path
    }

    if ( "" -eq $PolicyPrefix -and $True -ne $KeepPolicyIds ) {
        $PolicyPrefix = (Get-Item -Path ".\").Name
    }
    $global:PolicyPath = $PolicyPath
    $global:PolicyPrefix = $PolicyPrefix
    $global:ConfigPath = $ConfigPath
    $global:b2cAppSettings =(Get-Content -Path $ConfigPath | ConvertFrom-json)
    $global:InstrumentationKey=$b2cAppSettings.InstrumentationKey
    
    $env:B2CAppId=$b2cAppSettings.ClientCredentials.client_id
    $env:B2CAppKey=$b2cAppSettings.ClientCredentials.client_secret
    $global:B2CAppId=$b2cAppSettings.ClientCredentials.client_id
    $global:B2CAppKey=$b2cAppSettings.ClientCredentials.client_secret
    
    if ( $null -ne $b2cAppSettings.AzureStorageAccount ) {
        $global:uxStorageAccount=$b2cAppSettings.AzureStorageAccount.AccountName
        $global:uxStorageAccountKey=$b2cAppSettings.AzureStorageAccount.AccountKey
        $global:uxTemplateLocation= "$($b2cAppSettings.AzureStorageAccount.ContainerName)/$($b2cAppSettings.AzureStorageAccount.Path)/" + $PolicyPrefix.ToLower()
        $global:EndpointSuffix=$b2cAppSettings.AzureStorageAccount.EndpointSuffix
        $global:storageConnectString="DefaultEndpointsProtocol=https;AccountName=$uxStorageAccount;AccountKey=$uxStorageAccountKey;EndpointSuffix=$EndpointSuffix"    
    }
    
    if ( "" -eq $TenantName ) {
        $TenantName = $b2cAppSettings.TenantName
    }
    
    if ( $True -eq $AzureCli ) {
        try {
            $tenant = (az account show | ConvertFrom-json)
        } catch {
            write-warning "Not logged in to a B2C tenant.`n Please run az cli -t {tenantId} or `n$PSScriptRoot\aadb2c-login.ps1 -t `"yourtenant`"`n`n"
            return
        }
        if ( !($TenantName -imatch ".onmicrosoft.com") ) {
            $TenantName = $TenantName + ".onmicrosoft.com"
        }
        $resp = Invoke-RestMethod -Uri "https://login.windows.net/$TenantName/v2.0/.well-known/openid-configuration"
        $tenantID = $resp.authorization_endpoint.Split("/")[3]
    } else {
        try {
            $tenant = Get-AzureADTenantDetail
        } catch {
            write-warning "Not logged in to a B2C tenant.`n Please run Connect-AzureADB2C -t `"yourtenant`"`n`n"
            return
        }
        if ( $tenantName -ne $tenant.VerifiedDomains[0].Name) {
            write-error "Logged in to the wrong B2C tenant.`nTarget:`t$TenantName`nLogged in to:`t$($tenant.VerifiedDomains[0].Name)`n`n"
            return
        }
        $tenantName = $tenant.VerifiedDomains[0].Name
        $tenantID = $tenant.ObjectId
    }
    $global:tenantName = $tenantName
    $global:tenantID = $tenantID
    
    write-output "Config File    :`t$ConfigPath"
    write-output "B2C Tenant     :`t$tenantID, $tenantName"
    write-output "B2C Client Cred:`t$($env:B2CAppId), $($app.DisplayName)"
    write-output "Policy Prefix  :`t$PolicyPrefix"
        
}

function Get-AzureADB2CAccessToken([string]$tenantId) {
    $cache = [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared
    if ( "" -eq $tenantId ) {
        $item =$cache.ReadItems()| where-object {$_.TenantId -eq $global:tenantId }
    } else {
        $item =$cache.ReadItems()| where-object {$_.TenantId -eq $tenantId }
    }
    return $item.AccessToken
}

function Set-AzureADB2CClaimsProvider (
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",    
    [Parameter(Mandatory=$true)][Alias('i')][string]$ProviderName = "",    # google, twitter, amazon, linkedid, AzureAD
    [Parameter(Mandatory=$false)][Alias('c')][string]$client_id = "",    # client_id/AppId o the IdpName
    [Parameter(Mandatory=$false)][Alias('a')][string]$AadTenantName = "",    # contoso.com or contoso
    [Parameter(Mandatory=$false)][Alias('b')][string]$BasePolicyFileName = "TrustFrameworkBase.xml",
    [Parameter(Mandatory=$false)][Alias('e')][string]$ExtPolicyFileName = "TrustFrameworkExtensions.xml"
)
{

if ( "" -eq $PolicyPath ) {
    $PolicyPath = (get-location).Path
}
    
if ( "" -eq $client_id ) {
  $client_id = ($global:b2cAppSettings.ClaimsProviders | where {$_.Name -eq $ProviderName }).client_id
}

if ( "" -eq $AadTenantName -and "azuread" -eq $ProviderName.ToLower() ) {
  $AadTenantName = ($global:b2cAppSettings.ClaimsProviders | where {$_.Name -eq $ProviderName }).DomainName
}

[xml]$base =Get-Content -Path "$PolicyPath/$BasePolicyFileName" -Raw
[xml]$ext =Get-Content -Path "$PolicyPath/$ExtPolicyFileName" -Raw

$googleTPId = "Google-OAuth"
$googleClaimsExchangeId="GoogleExchange"
$googleCP=@"
<ClaimsProvider>
  <Domain>google.com</Domain>
  <DisplayName>Google</DisplayName>
  <TechnicalProfiles>
    <TechnicalProfile Id="Google-OAUTH">
      <DisplayName>Google</DisplayName>
      <Protocol Name="OAuth2" />
      <Metadata>
        <Item Key="ProviderName">google</Item>
        <Item Key="authorization_endpoint">https://accounts.google.com/o/oauth2/auth</Item>
        <Item Key="AccessTokenEndpoint">https://accounts.google.com/o/oauth2/token</Item>
        <Item Key="ClaimsEndpoint">https://www.googleapis.com/oauth2/v1/userinfo</Item>
        <Item Key="scope">email profile</Item>
        <Item Key="HttpBinding">POST</Item>
        <Item Key="UsePolicyInRedirectUri">0</Item>
        <Item Key="client_id">{client_id}</Item>
      </Metadata>
      <CryptographicKeys>
        <Key Id="client_secret" StorageReferenceId="B2C_1A_GoogleSecret" />
      </CryptographicKeys>
      <OutputClaims>
        <OutputClaim ClaimTypeReferenceId="issuerUserId" PartnerClaimType="id" />
        <OutputClaim ClaimTypeReferenceId="email" PartnerClaimType="email" />
        <OutputClaim ClaimTypeReferenceId="givenName" PartnerClaimType="given_name" />
        <OutputClaim ClaimTypeReferenceId="surname" PartnerClaimType="family_name" />
        <OutputClaim ClaimTypeReferenceId="displayName" PartnerClaimType="name" />
        <OutputClaim ClaimTypeReferenceId="identityProvider" DefaultValue="google.com" />
        <OutputClaim ClaimTypeReferenceId="authenticationSource" DefaultValue="socialIdpAuthentication" />
      </OutputClaims>
      <OutputClaimsTransformations>
        <OutputClaimsTransformation ReferenceId="CreateRandomUPNUserName" />
        <OutputClaimsTransformation ReferenceId="CreateUserPrincipalName" />
        <OutputClaimsTransformation ReferenceId="CreateAlternativeSecurityId" />
        <OutputClaimsTransformation ReferenceId="CreateSubjectClaimFromAlternativeSecurityId" />
      </OutputClaimsTransformations>
      <UseTechnicalProfileForSessionManagement ReferenceId="SM-SocialLogin" />
    </TechnicalProfile>
  </TechnicalProfiles>
</ClaimsProvider>
"@

$twitterCP = @"
<ClaimsProvider>
  <Domain>twitter.com</Domain>
  <DisplayName>Twitter</DisplayName>
  <TechnicalProfiles>
    <TechnicalProfile Id="Twitter-OAUTH1">
      <DisplayName>Twitter</DisplayName>
      <Protocol Name="OAuth1" />
      <Metadata>
        <Item Key="ProviderName">Twitter</Item>
        <Item Key="authorization_endpoint">https://api.twitter.com/oauth/authenticate</Item>
        <Item Key="access_token_endpoint">https://api.twitter.com/oauth/access_token</Item>
        <Item Key="request_token_endpoint">https://api.twitter.com/oauth/request_token</Item>
        <Item Key="ClaimsEndpoint">https://api.twitter.com/1.1/account/verify_credentials.json?include_email=true</Item>
        <Item Key="ClaimsResponseFormat">json</Item>
        <Item Key="client_id">{client_id}</Item>
      </Metadata>
      <CryptographicKeys>
        <Key Id="client_secret" StorageReferenceId="B2C_1A_TwitterSecret" />
      </CryptographicKeys>
      <OutputClaims>
        <OutputClaim ClaimTypeReferenceId="issuerUserId" PartnerClaimType="user_id" />
        <OutputClaim ClaimTypeReferenceId="displayName" PartnerClaimType="screen_name" />
        <OutputClaim ClaimTypeReferenceId="email" />
        <OutputClaim ClaimTypeReferenceId="identityProvider" DefaultValue="twitter.com" />
        <OutputClaim ClaimTypeReferenceId="authenticationSource" DefaultValue="socialIdpAuthentication" />
      </OutputClaims>
      <OutputClaimsTransformations>
        <OutputClaimsTransformation ReferenceId="CreateRandomUPNUserName" />
        <OutputClaimsTransformation ReferenceId="CreateUserPrincipalName" />
        <OutputClaimsTransformation ReferenceId="CreateAlternativeSecurityId" />
        <OutputClaimsTransformation ReferenceId="CreateSubjectClaimFromAlternativeSecurityId" />
      </OutputClaimsTransformations>
      <UseTechnicalProfileForSessionManagement ReferenceId="SM-SocialLogin" />
    </TechnicalProfile>
  </TechnicalProfiles>
</ClaimsProvider>
"@

$linkedinCP = @"
<ClaimsProvider>
  <Domain>linkedin.com</Domain>
  <DisplayName>LinkedIn</DisplayName>
  <TechnicalProfiles>
    <TechnicalProfile Id="LinkedIn-OAUTH">
      <DisplayName>LinkedIn</DisplayName>
      <Protocol Name="OAuth2" />
      <Metadata>
        <Item Key="ProviderName">linkedin</Item>
        <Item Key="authorization_endpoint">https://www.linkedin.com/oauth/v2/authorization</Item>
        <Item Key="AccessTokenEndpoint">https://www.linkedin.com/oauth/v2/accessToken</Item>
        <Item Key="ClaimsEndpoint">https://api.linkedin.com/v2/me</Item>
        <Item Key="scope">r_emailaddress r_liteprofile</Item>
        <Item Key="HttpBinding">POST</Item>
        <Item Key="external_user_identity_claim_id">id</Item>
        <Item Key="BearerTokenTransmissionMethod">AuthorizationHeader</Item>
        <Item Key="ResolveJsonPathsInJsonTokens">true</Item>
        <Item Key="UsePolicyInRedirectUri">0</Item>
        <Item Key="client_id">{client_id}</Item>
      </Metadata>
      <CryptographicKeys>
        <Key Id="client_secret" StorageReferenceId="B2C_1A_LinkedInSecret" />
      </CryptographicKeys>
      <InputClaims />
      <OutputClaims>
        <OutputClaim ClaimTypeReferenceId="issuerUserId" PartnerClaimType="id" />
        <OutputClaim ClaimTypeReferenceId="givenName" PartnerClaimType="firstName.localized" />
        <OutputClaim ClaimTypeReferenceId="surname" PartnerClaimType="lastName.localized" />
        <OutputClaim ClaimTypeReferenceId="identityProvider" DefaultValue="linkedin.com" AlwaysUseDefaultValue="true" />
        <OutputClaim ClaimTypeReferenceId="authenticationSource" DefaultValue="socialIdpAuthentication" AlwaysUseDefaultValue="true" />
      </OutputClaims>
      <OutputClaimsTransformations>
        <OutputClaimsTransformation ReferenceId="ExtractGivenNameFromLinkedInResponse" />
        <OutputClaimsTransformation ReferenceId="ExtractSurNameFromLinkedInResponse" />
        <OutputClaimsTransformation ReferenceId="CreateRandomUPNUserName" />
        <OutputClaimsTransformation ReferenceId="CreateUserPrincipalName" />
        <OutputClaimsTransformation ReferenceId="CreateAlternativeSecurityId" />
        <OutputClaimsTransformation ReferenceId="CreateSubjectClaimFromAlternativeSecurityId" />
      </OutputClaimsTransformations>
      <UseTechnicalProfileForSessionManagement ReferenceId="SM-SocialLogin" />
    </TechnicalProfile>
  </TechnicalProfiles>
</ClaimsProvider>
"@

$amazonCP = @"
<ClaimsProvider>
  <Domain>amazon.com</Domain>
  <DisplayName>Amazon</DisplayName>
  <TechnicalProfiles>
    <TechnicalProfile Id="Amazon-OAUTH">
    <DisplayName>Amazon</DisplayName>
    <Protocol Name="OAuth2" />
    <Metadata>
      <Item Key="ProviderName">amazon</Item>
      <Item Key="authorization_endpoint">https://www.amazon.com/ap/oa</Item>
      <Item Key="AccessTokenEndpoint">https://api.amazon.com/auth/o2/token</Item>
      <Item Key="ClaimsEndpoint">https://api.amazon.com/user/profile</Item>
      <Item Key="scope">profile</Item>
      <Item Key="HttpBinding">POST</Item>
      <Item Key="UsePolicyInRedirectUri">0</Item>
      <Item Key="client_id">{client_id}</Item>
    </Metadata>
    <CryptographicKeys>
      <Key Id="client_secret" StorageReferenceId="B2C_1A_AmazonSecret" />
    </CryptographicKeys>
    <OutputClaims>
      <OutputClaim ClaimTypeReferenceId="issuerUserId" PartnerClaimType="user_id" />
      <OutputClaim ClaimTypeReferenceId="email" PartnerClaimType="email" />
      <OutputClaim ClaimTypeReferenceId="displayName" PartnerClaimType="name" />
      <OutputClaim ClaimTypeReferenceId="identityProvider" DefaultValue="amazon.com" />
      <OutputClaim ClaimTypeReferenceId="authenticationSource" DefaultValue="socialIdpAuthentication" />
    </OutputClaims>
      <OutputClaimsTransformations>
      <OutputClaimsTransformation ReferenceId="CreateRandomUPNUserName" />
      <OutputClaimsTransformation ReferenceId="CreateUserPrincipalName" />
      <OutputClaimsTransformation ReferenceId="CreateAlternativeSecurityId" />
    </OutputClaimsTransformations>
    <UseTechnicalProfileForSessionManagement ReferenceId="SM-SocialLogin" />
    </TechnicalProfile>
  </TechnicalProfiles>
</ClaimsProvider>
"@

$msaCP = @"
<ClaimsProvider>
  <Domain>live.com</Domain>
  <DisplayName>Microsoft Account</DisplayName>
  <TechnicalProfiles>
    <TechnicalProfile Id="MSA-OIDC">
      <DisplayName>Microsoft Account</DisplayName>
      <Protocol Name="OpenIdConnect" />
      <Metadata>
        <Item Key="ProviderName">https://login.live.com</Item>
        <Item Key="METADATA">https://login.live.com/.well-known/openid-configuration</Item>
        <Item Key="response_types">code</Item>
        <Item Key="response_mode">form_post</Item>
        <Item Key="scope">openid profile email</Item>
        <Item Key="HttpBinding">POST</Item>
        <Item Key="UsePolicyInRedirectUri">0</Item>
        <Item Key="client_id">{client_id}</Item>
      </Metadata>
      <CryptographicKeys>
        <Key Id="client_secret" StorageReferenceId="B2C_1A_MSASecret" />
      </CryptographicKeys>
      <OutputClaims>
        <OutputClaim ClaimTypeReferenceId="issuerUserId" PartnerClaimType="oid" />
        <OutputClaim ClaimTypeReferenceId="givenName" PartnerClaimType="given_name" />
        <OutputClaim ClaimTypeReferenceId="surName" PartnerClaimType="family_name" />
        <OutputClaim ClaimTypeReferenceId="displayName" PartnerClaimType="name" />
        <OutputClaim ClaimTypeReferenceId="authenticationSource" DefaultValue="socialIdpAuthentication" />
        <OutputClaim ClaimTypeReferenceId="identityProvider" PartnerClaimType="iss" />
        <OutputClaim ClaimTypeReferenceId="email" />
      </OutputClaims>
      <OutputClaimsTransformations>
        <OutputClaimsTransformation ReferenceId="CreateRandomUPNUserName" />
        <OutputClaimsTransformation ReferenceId="CreateUserPrincipalName" />
        <OutputClaimsTransformation ReferenceId="CreateAlternativeSecurityId" />
        <OutputClaimsTransformation ReferenceId="CreateSubjectClaimFromAlternativeSecurityId" />
      </OutputClaimsTransformations>
      <UseTechnicalProfileForSessionManagement ReferenceId="SM-SocialLogin" />
    </TechnicalProfile>
  </TechnicalProfiles>
</ClaimsProvider>
"@

$facebookCP = @"
<ClaimsProvider>
<DisplayName>Facebook</DisplayName>
<TechnicalProfiles>
  <TechnicalProfile Id="Facebook-OAUTH">
    <Metadata>
      <Item Key="client_id">{client_id}</Item>
      <Item Key="scope">email public_profile</Item>
      <Item Key="ClaimsEndpoint">https://graph.facebook.com/me?fields=id,first_name,last_name,name,email</Item>
    </Metadata>
  </TechnicalProfile>
</TechnicalProfiles>
</ClaimsProvider>
"@

$aadSingleTenantCP = @"
<ClaimsProvider>
  <Domain>{AadTenantFQDN}</Domain>
  <DisplayName>Login using {AadTenantDisplayName}</DisplayName>
  <TechnicalProfiles>
    <TechnicalProfile Id="{tpId}">
      <DisplayName>{AadTenantDisplayName} Employee</DisplayName>
      <Description>Login with your {AadTenantDisplayName} account</Description>
      <Protocol Name="OpenIdConnect"/>
      <Metadata>
        <Item Key="METADATA">https://login.microsoftonline.com/{AadTenantFQDN}/v2.0/.well-known/openid-configuration</Item>
        <Item Key="client_id">{client_id}</Item>
        <Item Key="response_types">code</Item>
        <Item Key="scope">openid profile</Item>
        <Item Key="response_mode">form_post</Item>
        <Item Key="HttpBinding">POST</Item>
        <Item Key="UsePolicyInRedirectUri">false</Item>
      </Metadata>
      <CryptographicKeys>
        <Key Id="client_secret" StorageReferenceId="B2C_1A_{AadTenantDisplayName}AppSecret"/>
      </CryptographicKeys>
      <OutputClaims>
        <OutputClaim ClaimTypeReferenceId="issuerUserId" PartnerClaimType="oid"/>
        <OutputClaim ClaimTypeReferenceId="tenantId" PartnerClaimType="tid"/>
        <OutputClaim ClaimTypeReferenceId="givenName" PartnerClaimType="given_name" />
        <OutputClaim ClaimTypeReferenceId="surName" PartnerClaimType="family_name" />
        <OutputClaim ClaimTypeReferenceId="displayName" PartnerClaimType="name" />
        <OutputClaim ClaimTypeReferenceId="authenticationSource" DefaultValue="socialIdpAuthentication" AlwaysUseDefaultValue="true" />
        <OutputClaim ClaimTypeReferenceId="identityProvider" PartnerClaimType="iss" />
      </OutputClaims>
      <OutputClaimsTransformations>
        <OutputClaimsTransformation ReferenceId="CreateRandomUPNUserName"/>
        <OutputClaimsTransformation ReferenceId="CreateUserPrincipalName"/>
        <OutputClaimsTransformation ReferenceId="CreateAlternativeSecurityId"/>
        <OutputClaimsTransformation ReferenceId="CreateSubjectClaimFromAlternativeSecurityId"/>
      </OutputClaimsTransformations>
      <UseTechnicalProfileForSessionManagement ReferenceId="SM-SocialLogin"/>
    </TechnicalProfile>
  </TechnicalProfiles>
</ClaimsProvider>
"@

$tpId = ""
$claimsExchangeId=""
$claimsProviderXml=""

switch ( $ProviderName.ToLower() ) {
  "google" { $tpId = "Google-OAUTH"; $claimsExchangeId="GoogleExchange"; $claimsProviderXml = $googleCP }
  "twitter" { $tpId = "Twitter-OAUTH1"; $claimsExchangeId="TwitterExchange"; $claimsProviderXml = $twitterCP }
  "linkedin" { $tpId = "LinkedIn-OAUTH"; $claimsExchangeId="LinkedinExchange"; $claimsProviderXml = $linkedinCP }
  "amazon" { $tpId = "Amazon-OAUTH"; $claimsExchangeId="AmazonExchange"; $claimsProviderXml = $amazonCP }
  "msa" { $tpId = "MSA-OIDC"; $claimsExchangeId="MicrosoftAccountExchange"; $claimsProviderXml = $msaCP }
  "facebook" { $tpId = "Facebook-OAUTH"; $claimsExchangeId="FacebookExchange"; $claimsProviderXml = $msaCP }
  "azuread" {
      if ( $AadTenantName -imatch ".com" ) {
        $AadTenantDisplayName = $AadTenantName.Split(".")[0]
        $AadTenantFQDN = $AadTenantName
      } else {
        $AadTenantDisplayName = $AadTenantName 
        $AadTenantFQDN = $AadTenantName + ".onmicrosoft.com"
      }
      $AadTenantDisplayName = $AadTenantDisplayName.Substring(0,1).ToUpper() + $AadTenantDisplayName.Substring(1)
      $tpId = $AadTenantDisplayName + "-OIDC"
      $claimsExchangeId= $AadTenantDisplayName + "Exchange"
      $claimsProviderXml = $aadSingleTenantCP
  }
  default { write-error "IdP name must be either or google, twitter, linkedin, amazon, facebook, azuread or msa"; return }
}

if ( $ext.TrustFrameworkPolicy.ClaimsProviders.InnerXml -imatch $tpId ) {
  if ( "Facebook-OAUTH" -eq $tpId) {
    write-output "Updating TechnicalProfileId $tpId"
    $ext.TrustFrameworkPolicy.InnerXml = $ext.TrustFrameworkPolicy.InnerXml.Replace( "facebook_clientid", $client_id) 
    $ext.Save("$PolicyPath/TrustFrameworkExtensions.xml")        
    return
  }
  write-warning "TechnicalProfileId $tpId already exists in policy"
  return
}

write-output "Adding TechnicalProfileId $tpId"

$claimsProviderXml = $claimsProviderXml.Replace("{client_id}", $client_id)
if ( "azuread" -eq $ProviderName.ToLower() ) {
  $claimsProviderXml = $claimsProviderXml.Replace("{tpId}", $tpId)
  $claimsProviderXml = $claimsProviderXml.Replace("{AadTenantName}", $AadTenantName)
  $claimsProviderXml = $claimsProviderXml.Replace("{AadTenantDisplayName}", $AadTenantDisplayName)
  $claimsProviderXml = $claimsProviderXml.Replace("{AadTenantFQDN}", $AadTenantFQDN)
}
$copyFromBase = $false
if ( $null -eq $ext.TrustFrameworkPolicy.UserJourneys ) {
  # copy from Base
  $copyFromBase = $true
  $userJourney = $base.TrustFrameworkPolicy.UserJourneys.UserJourney[0].Clone()
  for( $i = 2; $i -lt $userJourney.OrchestrationSteps.OrchestrationStep.Length; ) {
      $ret = $userJourney.OrchestrationSteps.RemoveChild($userJourney.OrchestrationSteps.OrchestrationStep[$i])
  }
  $ret = $userJourney.RemoveChild($userJourney.ClientDefinition) 
} else {
  # build on existing
  $userJourney = $ext.TrustFrameworkPolicy.UserJourneys.UserJourney
}

$ext.TrustFrameworkPolicy.ClaimsProviders.innerXml = $ext.TrustFrameworkPolicy.ClaimsProviders.innerXml + $claimsProviderXml

$claimsProviderSelection = "<ClaimsProviderSelection TargetClaimsExchangeId=`"$claimsExchangeId`"/>"
$userJourney.OrchestrationSteps.OrchestrationStep[0].ClaimsProviderSelections.InnerXml = $userJourney.OrchestrationSteps.OrchestrationStep[0].ClaimsProviderSelections.InnerXml + $claimsProviderSelection

$claimsExchangeTP = "<ClaimsExchange Id=`"$claimsExchangeId`" TechnicalProfileReferenceId=`"$tpId`"/>"
$userJourney.OrchestrationSteps.OrchestrationStep[1].ClaimsExchanges.InnerXml = $userJourney.OrchestrationSteps.OrchestrationStep[1].ClaimsExchanges.InnerXml + $claimsExchangeTP

if ( $true -eq $copyFromBase ) {
  try {
    $ext.TrustFrameworkPolicy.InnerXml = $ext.TrustFrameworkPolicy.InnerXml.Replace( "<!--UserJourneys>", "<UserJourneys>" + $userJourney.OuterXml + "</UserJourneys>") 
  } Catch {}
}
$ext.TrustFrameworkPolicy.InnerXml = $ext.TrustFrameworkPolicy.InnerXml.Replace( "xmlns=`"`"", "") 

$ext.Save("$PolicyPath/TrustFrameworkExtensions.xml")

}

function New-AzureADB2CIdentityExperienceFrameworkApps
(
    [Parameter(Mandatory=$false)][Alias('n')][string]$DisplayName = "IdentityExperienceFramework",
    [Parameter(Mandatory=$false)][boolean]$AzureCli = $False         # if to force Azure CLI on Windows
)
{
    $isWinOS = ($env:PATH -imatch "/usr/bin" )                 # Mac/Linux
    if ( $isWinOS ) { $AzureCLI = $True}

    if ( $False -eq $AzureCli ) {
        write-host "Getting Tenant info..."
        $tenant = Get-AzureADTenantDetail
        $tenantName = $tenant.VerifiedDomains[0].Name
        $tenantID = $tenant.ObjectId
    } else {
        $tenantName = $global:tenantName
        $tenantID = $global:tenantID
    }
    write-host "$tenantName`n$tenantId"

    $AzureAdGraphApiAppID = "00000002-0000-0000-c000-000000000000"  # https://graph.windows.net
    $scopeUserReadId = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"       # User.Read
    $scopeUserRead = "User.Read"

    $ProxyDisplayName = "Proxy$DisplayName"

    if ( $False -eq $AzureCli ) {
        $req1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
        $req1.ResourceAppId = $AzureAdGraphApiAppID
        $req1.ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList $scopeUserReadId,"Scope"
        write-host "`nCreating WebApp $DisplayName..."
        $appIEF = New-AzureADApplication -DisplayName $DisplayName -IdentifierUris "http://$TenantName/$DisplayName" -ReplyUrls @("https://$DisplayName") -RequiredResourceAccess $req1 # WebApp
        write-output "AppID`t`t$($appIEF.AppId)`nObjectID:`t$($appIEF.ObjectID)"
        write-host "Creating ServicePrincipal..."
        $sp = New-AzureADServicePrincipal -AccountEnabled $true -AppId $appIEF.AppId -AppRoleAssignmentRequired $false -DisplayName $DisplayName 
        write-host "AppID`t`t$($sp.AppId)`nObjectID:`t$($sp.ObjectID)"

        $req2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
        $req2.ResourceAppId = $appIEF.AppId
        $req2.ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList $appIEF.Oauth2Permissions.Id,"Scope"

        write-host "`nCreating NativeApp $ProxyDisplayName..."
        $appPIEF = New-AzureADApplication -DisplayName $ProxyDisplayName -ReplyUrls @("https://$ProxyDisplayName") -RequiredResourceAccess @($req1,$req2) -PublicClient $true # NativeApp
        write-output "AppID`t`t$($appPIEF.AppId)`nObjectID:`t$($appPIEF.ObjectID)"
        write-host "Creating ServicePrincipal..."
        $sp = New-AzureADServicePrincipal -AccountEnabled $true -AppId $appPIEF.AppId -AppRoleAssignmentRequired $false -DisplayName $ProxyDisplayName 
        write-host "AppID`t`t$($sp.AppId)`nObjectID:`t$($sp.ObjectID)"

        Set-AzureADB2CGrantPermissions -n $DisplayName
        Set-AzureADB2CGrantPermissions -n $ProxyDisplayName
    } else {
        write-host "Creating $DisplayName"
        $resAccessUserRead =  "{`"`"resourceAppId`"`": `"`"$AzureAdGraphApiAppID`"`",`"`"resourceAccess`"`":[{`"`"id`"`": `"`"$scopeUserReadId`"`",`"`"type`"`":`"`"Scope`"`"}]}"
        $appIEF = (az ad app create --display-name $DisplayName --identifier-uris "http://$TenantName/$DisplayName" --reply-urls "https://$DisplayName" --required-resource-accesses "[$resAccessUserRead]" | ConvertFrom-json)
        $spIEF = (az ad sp create --id $appIEF.appId | ConvertFrom-json)
        write-host $appIEF.appId

        write-host "Creating $ProxyDisplayName"
        $resAccessP="[{`"`"resourceAccess`"`":[{`"`"id`"`":`"`"$($appIEF.Oauth2Permissions.id)`"`",`"`"type`"`":`"`"Scope`"`"}],`"`"resourceAppId`"`":`"`"$($appIEF.appId)`"`"},$resAccessUserRead]"
        $appPIEF = (az ad app create --display-name $ProxyDisplayName --native-app --reply-urls "https://$ProxyDisplayName" --required-resource-accesses $resAccessP | ConvertFrom-Json)
        $spPIEF = (az ad sp create --id $appPIEF.appId | ConvertFrom-json)
        write-host $appPIEF.appId
        
        $appGraph = (az ad sp list --spn "https://graph.windows.net" | convertFrom-json)

        write-host "Granting Permissions for $DisplayName"
        $res = (az ad app permission grant --id $appIEF.appId --api $appGraph.objectId --scope $scopeUserRead --consent-type "AllPrincipals" | ConvertFrom-json)

        write-host "Granting Permissions for $ProxyDisplayName"
        $res = (az ad app permission grant --id $appPIEF.appId --api $appGraph.objectId --scope $scopeUserRead --consent-type "AllPrincipals" | ConvertFrom-json)
        $res = (az ad app permission grant --id $appPIEF.appId --api $appIEF.appId --consent-type "AllPrincipals" | ConvertFrom-json)
    }

}

function Set-AzureADB2CGrantPermissions
(
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('a')][string]$AppID = "",
    [Parameter(Mandatory=$false)][Alias('k')][string]$AppKey = "",
    [Parameter(Mandatory=$true)][Alias('n')][string]$AppDisplayName = ""
)
{
    $oauth = $null
    if ( "" -eq $AppID ) { $AppID = $env:B2CAppId }
    if ( "" -eq $AppKey ) { $AppKey = $env:B2CAppKey }

    $tenantID = ""
    if ( "" -eq $TenantName ) {
        write-host "Getting Tenant info..."
        $tenant = Get-AzureADTenantDetail
        if ( $null -eq $tenant ) {
            write-error "Not logged in to a B2C tenant"
            return
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
        write-error "Unknown Tenant"
        return
    }
    write-host "Tenant:  `t$tenantName`nTenantID:`t$tenantId"

    $app = Get-AzureADApplication -All $true | where-object {$_.DisplayName -eq $AppDisplayName } -ErrorAction SilentlyContinue
    $sp = Get-AzureADServicePrincipal -All $true | where-object {$_.DisplayName -eq $AppDisplayName } -ErrorAction SilentlyContinue

    if ( $null -eq $app -or $null -eq $sp ) {
        write-error "No ServicePrincipal with name $AppDisplayName"
        return
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

}

function New-AzureADB2CPolicyKey
(
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('a')][string]$AppID = "",            # App reg in B2C that has permissions to create policy keys
    [Parameter(Mandatory=$false)][Alias('k')][string]$AppKey = "",           #
    [Parameter(Mandatory=$true)][Alias('n')][string]$KeyContainerName = "", # [B2C_1A_]Name
    [Parameter(Mandatory=$true)][Alias('y')][string]$KeyType = "secret",    # RSA, secret
    [Parameter(Mandatory=$true)][Alias('u')][string]$KeyUse = "sig",        # sig, enc
    [Parameter(Mandatory=$false)][Alias('s')][string]$Secret = ""           # used when $KeyType==secret
)
{
    $oauth = $null
    if ( "" -eq $AppID ) { $AppID = $env:B2CAppId }
    if ( "" -eq $AppKey ) { $AppKey = $env:B2CAppKey }
    $KeyType = $KeyType.ToLower()
    $KeyUse = $KeyUse.ToLower()

    if ( !("rsa" -eq $KeyType -or "secret" -eq $KeyType ) ) {
        write-error "KeyType must be RSA or secret"
        return
    }
    if ( !("sig" -eq $KeyUse -or "enc" -eq $KeyUse ) ) {
        write-error "KeyUse must be sig(nature) or enc(ryption)"
        return
    }
    if ( $false -eq $KeyContainerName.StartsWith("B2C_1A_") ) {
        $KeyContainerName = "B2C_1A_$KeyContainerName"
    }

    if ( "" -eq $TenantName ) {
        $tenantName = $global:TenantName
        $tenantID = $global:tenantId
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
        write-warning "$($resp.id) already has $($resp.keys.Length) keys"
        return
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
}

function New-AzureADB2CTestApp
(
    [Parameter(Mandatory=$true)][Alias('n')][string]$DisplayName = "Test-WebApp",
    [Parameter(Mandatory=$false)][Alias('a')][string]$AppID = "",
    [Parameter(Mandatory=$false)][Alias('k')][string]$AppKey = "",
    [Parameter(Mandatory=$false)][boolean]$AzureCli = $False         # if to force Azure CLI on Windows
)
{
    $oauth = $null
    if ( "" -eq $AppID ) { $AppID = $env:B2CAppId }
    if ( "" -eq $AppKey ) { $AppKey = $env:B2CAppKey }

    $tenantName = $global:tenantName

    $isWinOS = ($env:PATH -imatch "/usr/bin" )                 # Mac/Linux
    if ( $isWinOS ) { $AzureCLI = $True}

    $requiredResourceAccess=@"
    [
        {
            "resourceAppId": "00000003-0000-0000-c000-000000000000",
            "resourceAccess": [
                {
                    "id": "37f7f235-527c-4136-accd-4a02d197296e",
                    "type": "Scope"
                },
                {
                    "id": "7427e0e9-2fba-42fe-b0c0-848c9e6a8182",
                    "type": "Scope"
                }
            ]
        }
    ]
"@ | ConvertFrom-json

    if ( $False -eq $AzureCli ) {
        $reqAccess=@()
        foreach( $resApp in $requiredResourceAccess ) {
            $req = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
            $req.ResourceAppId = $resApp.resourceAppId
            foreach( $ra in $resApp.resourceAccess ) {
                $req.ResourceAccess += New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList $ra.Id,$ra.type
            }
            $reqAccess += $req
        }
        write-output "Creating application $DisplayName"
        $app = New-AzureADApplication -DisplayName $DisplayName -IdentifierUris "https://$TenantName/$DisplayName" -ReplyUrls @("https://jwt.ms") -RequiredResourceAccess $reqAccess -Oauth2AllowImplicitFlow $true

        write-output "Creating ServicePrincipal $DisplayName"
        $sp = New-AzureADServicePrincipal -AccountEnabled $true -AppId $App.AppId -AppRoleAssignmentRequired $false -DisplayName $DisplayName 
    } else {
        write-output "Creating application $DisplayName"
        $app = (az ad app create --display-name $DisplayName --identifier-uris "http://$TenantName/$DisplayName" --reply-urls "https://jwt.ms" --oauth2-allow-implicit-flow true | ConvertFrom-json)

        write-output "Creating ServicePrincipal $DisplayName"
        $sp = (az ad sp create --id $app.appId | ConvertFrom-json)

        foreach( $resApp in $requiredResourceAccess ) {
            $rApp = (az ad sp list --filter "appId eq '$($resApp.resourceAppId)'" | ConvertFrom-json)
            $rApp.DisplayName
            foreach( $ra in $resApp.resourceAccess ) {
                $ret = (az ad app permission add --id $sp.appId --api $resApp.resourceAppId --api-permissions "$($ra.Id)=$($ra.type)")
                if ( "Scope" -eq $ra.type) {
                    $perm = ($rApp.oauth2Permissions | where { $_.id -eq "$($ra.Id)"})
                } else {
                    $perm = ($rApp.appRoles | where { $_.id -eq "$($ra.Id)"})
                }
                $perm.Value
            }        
        }
        az ad app permission admin-consent --id $sp.appId 
    }
    # -----------------------------------------------------------------------------------------
    # Patch WebApp with attributes Poweshell can't
    # -----------------------------------------------------------------------------------------

    Start-Sleep 15 # replication

    $oauthBody  = @{grant_type="client_credentials";resource="https://graph.microsoft.com/";client_id=$AppID;client_secret=$AppKey;scope="https://graph.microsoft.com/.default Application.ReadWrite.All"}
    $oauth      = Invoke-RestMethod -Method Post -Uri "https://login.microsoft.com/$tenantName/oauth2/token?api-version=1.0" -Body $oauthBody

    $apiUrl = "https://graph.microsoft.com/v1.0/applications/$($app.objectId)"
    $body = @{ api = @{ requestedAccessTokenVersion = 2 }; SignInAudience = "AzureADandPersonalMicrosoftAccount" }
    Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization = "Bearer $($oauth.access_token)" }  -Method PATCH -Body ($body | ConvertTo-json) -ContentType "application/json"

    if ( $False -eq $AzureCli ) {
        Set-AzureADB2CGrantPermissions -n $DisplayName
    }

}

function Push-AzureADB2CHtmlContent (
    [Parameter(Mandatory=$true)][Alias('f')][string]$LocalFile = "",
    [Parameter(Mandatory=$false)][Alias('a')][string]$StorageAccountName = "",
    [Parameter(Mandatory=$false)][Alias('p')][string]$ContainerPath = "",
    [Parameter(Mandatory=$false)][Alias('k')][string]$StorageAccountKey = "",
    [Parameter(Mandatory=$false)][Alias('e')][string]$EndpointSuffix = "core.windows.net"
    )
{
    $body = (Get-Content $LocalFile)
    $FileName = Split-Path $LocalFile -leaf

    if ( "" -eq $StorageAccountName ) { $StorageAccountName = $global:b2cAppSettings.AzureStorageAccount.AccountName}
    if ( "" -eq $StorageAccountKey ) { $StorageAccountKey = $global:b2cAppSettings.AzureStorageAccount.AccountKey}
    if ( "" -eq $ContainerPath) { $ContainerPath = "$($global:b2cAppSettings.AzureStorageAccount.ContainerName)/$($global:b2cAppSettings.AzureStorageAccount.Path)" }

    $StorageContainerName = $ContainerPath.Split("/")[0]
    $Path = $ContainerPath.Substring($StorageContainerName.Length+1)

    $Url = "https://$StorageAccountName.blob.$EndpointSuffix/$StorageContainerName/$path/$Filename"

    $contentType = "text/html"
    try {
        Add-Type -AssemblyName "System.Web"
        $contentType = [System.Web.MimeMapping]::GetMimeMapping($FileName)
    } catch {
        if ( $FileName.EndsWith(".css")) { $contentType = = "text/css" }
        if ( $FileName.EndsWith(".jpg") -or $FileName.EndsWith(".jpeg")) { $contentType = = "image/jpeg" }
        if ( $FileName.EndsWith(".png")) { $contentType = = "image/png" }
        if ( $FileName.EndsWith(".js")) { $contentType = = "application/x-javascript" }
    }
    $method = "PUT"
    $headerDate = '2014-02-14'
    $headers = @{"x-ms-version"="$headerDate"}
    $xmsdate = (get-date -format r).ToString()
    $headers.Add("x-ms-date",$xmsdate)
    $bytes = ([System.Text.Encoding]::UTF8.GetBytes($body))
    $contentLength = $bytes.length
    $headers.Add("Content-Length","$contentLength")
    #$headers.Add("Content-Type","$contentType")
    $headers.Add("x-ms-blob-type","BlockBlob")

    $signatureString = "$method$([char]10)$([char]10)$([char]10)$contentLength$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)"
    #Add CanonicalizedHeaders
    $signatureString += "x-ms-blob-type:" + $headers["x-ms-blob-type"] + "$([char]10)"
    $signatureString += "x-ms-date:" + $headers["x-ms-date"] + "$([char]10)"
    $signatureString += "x-ms-version:" + $headers["x-ms-version"] + "$([char]10)"
    #$signatureString += "Content-Type:" + $headers["Content-Type"] + "$([char]10)"
    #Add CanonicalizedResource
    $uri = New-Object System.Uri -ArgumentList $url
    $signatureString += "/" + $StorageAccountName + $uri.AbsolutePath
    $dataToMac = [System.Text.Encoding]::UTF8.GetBytes($signatureString)
    $accountKeyBytes = [System.Convert]::FromBase64String($StorageAccountKey)
    $hmac = new-object System.Security.Cryptography.HMACSHA256((,$accountKeyBytes))
    $signature = [System.Convert]::ToBase64String($hmac.ComputeHash($dataToMac))
    $headers.Add("Authorization", "SharedKey " + $StorageAccountName + ":" + $signature);

    write-host "PUT $LocalFile ==> $Url`r`n$contentLength byte(s)"
    $resp = Invoke-RestMethod -Uri $Url -Method $method -headers $headers -Body $body #-ContentType $contentType
    $resp
}
