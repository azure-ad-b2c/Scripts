# ---------------------------------------------------------------------------------------------------
# some simple wrappers around each type of GraphAPI CRUD call
# ---------------------------------------------------------------------------------------------------

$GraphEndpoint="https://graph.microsoft.com/beta"

function RefreshTokenIfExpired() {
    if ( $global:authMethod -eq "Connect-AzADB2CClientCredentials" ) {
        if ( [int]$global:token_expires_on -le [int](Get-Date -UFormat %s -Millisecond 0) ) {
            $resp = Connect-AzADB2CClientCredentials -Scope "https://graph.microsoft.com/.default"    
        }
    } # for DeviceLogin, you have to issue the command and login again
}
function Invoke-GraphRestMethodGet( 
    [Parameter(Mandatory=$true)][string]$path, 
    [Parameter(Mandatory=$false)][string]$ContentType = "application/json"
)
{
    return Invoke-RestMethod -Uri "$GraphEndpoint/$path" -Headers $global:authHeader -Method "GET" -ContentType $ContentType -ErrorAction Stop
}

function Invoke-GraphRestMethodPost( 
    [Parameter(Mandatory=$true)][string]$path, 
    [Parameter(Mandatory=$true)][string]$body, 
    [Parameter(Mandatory=$false)][string]$ContentType = "application/json"
)
{
    return Invoke-RestMethod -Uri "$GraphEndpoint/$path" -Headers $global:authHeader -Method "POST" -Body $body -ContentType $ContentType -ErrorAction Stop
}
function Invoke-GraphRestMethodPatch( 
    [Parameter(Mandatory=$true)][string]$path, 
    [Parameter(Mandatory=$true)][string]$body, 
    [Parameter(Mandatory=$false)][string]$ContentType = "application/json"
)
{
    return Invoke-RestMethod -Uri "$GraphEndpoint/$path" -Headers $global:authHeader -Method "PATCH" -Body $body -ContentType $ContentType -ErrorAction Stop
}
function Invoke-GraphRestMethodPut( 
    [Parameter(Mandatory=$true)][string]$path, 
    [Parameter(Mandatory=$true)][string]$body, 
    [Parameter(Mandatory=$false)][string]$ContentType = "application/json"
)
{
    return Invoke-RestMethod -Uri "$GraphEndpoint/$path" -Headers $global:authHeader -Method "PUT" -Body $body -ContentType $ContentType -ErrorAction Stop
}
function Invoke-GraphRestMethodDelete( 
    [Parameter(Mandatory=$true)][string]$path, 
    [Parameter(Mandatory=$false)][string]$ContentType = "application/json"
)
{
    return Invoke-RestMethod -Uri "$GraphEndpoint/$path" -Headers $global:authHeader -Method "DELETE" -ContentType $ContentType -ErrorAction Stop
}

function Get-Application (
    [string]$Path = "", 
    [string]$DisplayName = "", 
    [string]$DisplayNameStartsWith = "", 
    [string]$Select = ""
) 
{
    $q = "?"
    if ( $Path.Length -gt 0 ) {
        $path = "applications/$path"
    } else {
        $path = "applications"
    }
    if ( $DisplayName.Length -gt 0 ) {
        $path += "$q`$filter=displayName eq '$DisplayName'"
        $q = "&"
    } elseif ( $DisplayNameStartsWith.Length -gt 0 ) {
        $path += "$q`$filter=startswith(displayName, '$DisplayNameStartsWith')"
        $q = "&"
    }
    if ( $select.Length -gt 0 ) {
        $path += "$q`$select=$select"
    }
    return Invoke-GraphRestMethodGet $path
}
function Get-ServicePrincipal (
    [string]$AppId = "", 
    [string]$Select = ""
) 
{
    $path = "servicePrincipals?`$filter=AppId eq '$AppId'"
    if ( $select.Length -gt 0 ) {
        $path += "&`$select=$select"
    }
    return Invoke-GraphRestMethodGet $path
}
function Connect-AzADB2CClientCredentials
(
    [Parameter(Mandatory=$false)][Alias('a')][string]$AppId = "", 
    [Parameter(Mandatory=$false)][Alias('k')][string]$AppKey = "",
    [Parameter(Mandatory=$false)][Alias('s')][string]$Scope = "User.Read" 
)
{
    if ( "" -eq $AppID ) { $AppID = $env:B2CAppId }
    if ( "" -eq $AppKey ) { $AppKey = $env:B2CAppKey }
    $ctx = Get-AzContext
    $oauthBody  = @{grant_type="client_credentials";resource="https://graph.microsoft.com/";client_id=$AppID;client_secret=$AppKey;scope=$Scope}
    $oauth      = Invoke-RestMethod -Method Post -Uri "https://login.microsoft.com/$($ctx.Tenant.Id)/oauth2/token?api-version=1.0" -Body $oauthBody    
    $authHeader = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"} 
    $global:authHeader = $authHeader
    $global:token_expires_on = $oauth.expires_on
    $global:authMethod = "Connect-AzADB2CClientCredentials"
    return $authHeader
}

function Get-BrowserInfo(
    [Parameter(Mandatory=$false)][Boolean]$Chrome = $False,
    [Parameter(Mandatory=$false)][Boolean]$Edge = $False,
    [Parameter(Mandatory=$false)][Boolean]$Firefox = $False,
    [Parameter(Mandatory=$false)][Boolean]$Incognito = $True,
    [Parameter(Mandatory=$false)][Boolean]$NewWindow = $True
)
{
    $pgm = "chrome.exe"
    $params = "--incognito --new-window"
    $isMacOS = ($env:PATH -imatch "/usr/bin" )                 # Mac/Linux      
    if ( !$IsMacOS ) {
        $Browser = ""
        if ( $Chrome ) { $Browser = "Chrome" }
        if ( $Edge ) { $Browser = "Edge" }
        if ( $Firefox ) { $Browser = "Firefox" }
        if ( $browser -eq "") {
            $browser = (Get-ItemProperty HKCU:\Software\Microsoft\windows\Shell\Associations\UrlAssociations\http\UserChoice).ProgId
        }
        $browser = $browser.Replace("HTML", "").Replace("URL", "")
        switch( $browser.ToLower() ) {        
            "firefox" { 
                $pgm = "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
                $params = (&{If($Incognito) {"-private "} Else {""}}) + (&{If($NewWindow) {"-new-window"} Else {""}})
            } 
            "chrome" { 
                $pgm = "chrome.exe"
                $params = (&{If($Incognito) {"--incognito "} Else {""}}) + (&{If($NewWindow) {"--new-window"} Else {""}})
            } 
            default { 
                $pgm = "msedge.exe"
                $params = (&{If($Incognito) {"-InPrivate "} Else {""}}) + (&{If($NewWindow) {"-new-window"} Else {""}})
            } 
        }  
    }
    return $pgm, $params
}
function Start-Browser(
    [Parameter(Mandatory=$false)][string]$pgm, 
    [Parameter(Mandatory=$false)][string]$params, 
    [Parameter(Mandatory=$false)][string]$url
) {
    if ( $env:PATH -imatch "/usr/bin" ) {                      # Mac/Linux      
        if ( $env:PATH -imatch "Apple" ) {                     # Mac
            $ret = [System.Diagnostics.Process]::Start("/usr/bin/open","$url")
        } else {
            & xdg-open $url                                    # Linux
        }
    } else {                                                   # Windows
        $ret = [System.Diagnostics.Process]::Start($pgm,"$params $url")
    }
}
function Get-TenantIdFromName(
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = ""
) {
    $resp = Invoke-RestMethod -Uri "https://login.windows.net/$TenantName/v2.0/.well-known/openid-configuration"
    $tenantID = $resp.authorization_endpoint.Split("/")[3]    
    return $tenantId
}
<#
.SYNOPSIS
    Gets an access token for the current user for a specific resource, like Microsoft Graph API

.DESCRIPTION
    Gets an access token for the current user for a specific resource, like Microsoft Graph API

.PARAMETER ResourceUrl
    Resource to acquire a token for, like https://graph.microsoft.com/

.EXAMPLE
    Get-MSGraphAPIAccessToken

.EXAMPLE
    Get-MSGraphAPIAccessToken -ResourceUrl "https://graph.microsoft.com/"
#>
function Get-MSGraphAPIAccessToken
( 
    [Parameter(Mandatory=$false)][Alias('r')][string]$ResourceUrl = "https://graph.microsoft.com/" 
)
{
    $ctx = Get-AzContext
    $token = (Get-AzAccessToken -ResourceUrl $ResourceUrl -TenantId $ctx.Tenant.Id)
    return $token
}

<#
.SYNOPSIS
    Connects to an Azure AD B2C tenant

.DESCRIPTION
    Conects to an Azure AD B2C tenant either via Connect-AzAccount command or az login for CLI version. After login, it sets up global constants

.PARAMETER TenantName
    Tenant to connect to. If not specified, tenant name must exist in ConfigPath

.PARAMETER ConfigPath
    ConfigPath to config file

.EXAMPLE
    Connect-AzADB2C -t "yourtenant"

.EXAMPLE
    Connect-AzADB2C -ConfigPath .\b2cAppSettings_yourtenant.json
#>
function Connect-AzADB2C
(
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('c')][string]$ConfigPath = ""
)
{
    # if you just specify "-t yourtenant", we try to see if there is a config file for that tenant
    if ( $tenantName.Length -gt 0 -and $ConfigPath.Length -eq 0 ) {
        $path = "$((get-location).Path)\b2cAppSettings_$TenantName.json"
        if ((Test-Path -Path $path -PathType Leaf) -eq $True ) {
            $ConfigPath = $path
        }
        $path = "$((get-location).Path)\b2cAppSettings_$TenantName.onmicrosoft.com.json"
        if ((Test-Path -Path $path -PathType Leaf) -eq $True ) {
            $ConfigPath = $path
        }
    }
    # expand tenant name to a long name
    if ( ($TenantName -imatch ".onmicrosoft.com") -eq $false ) {
        $TenantName = $TenantName + ".onmicrosoft.com"
    }
    # if config file specified, load it and its values
    $global:b2cAppSettings = $null
    if ( "" -ne $ConfigPath ) {
        $global:b2cAppSettings = (Get-Content -Path $ConfigPath | ConvertFrom-json)
        $Tenant = $global:b2cAppSettings.TenantName
        $TenantName = $global:b2cAppSettings.TenantName
    }
    if ( "" -eq $TenantName ) {
        write-error "Unknown Tenant. Either use the -TenantName or the -ConfigPath parameter"
        return
    }
    if ( $TenantName.Length -eq 36 -and $TenantName.Contains("-") -eq $true)  {
        $TenantID = $TenantName
    } else {
        $tenantID = Get-TenantIdFromName -TenantName $TenantName
        write-host $TenantID
    }
    
    $startTime = Get-Date
    
    $account = Connect-AzAccount -tenantid $TenantID
    $TenantId = $account.Context.Tenant.Id
    $user = $account.Context.Account.Id

    $finishTime = Get-Date
    $TotalTime = ($finishTime - $startTime).TotalSeconds
    write-host "Time: $TotalTime sec(s)"        
    
    # get objectId of current user
    $accessToken = (Get-AzAccessToken -TenantId $TenantId).Token
    $part1=$accessToken.Split(".")[1]
    $fill = ""
    if ( ($part1.Length % 4) -ne 0 ) {
        $fill = "="*(4 - ($part1.Length % 4))
    }
    $global:userObjectId = ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String( "$part1$fill" )) | ConvertFrom-json).oid

    $resp = Invoke-RestMethod -Method "GET" -Uri "https://login.microsoft.com/$tenantId/metadata/json/1"
    $TenantName = ($resp.allowedAudiences | where {$_ -imatch ".onmicrosoft.com"}).Split("@")[1]

    $TenantShort = $TenantName.Replace(".onmicrosoft.com", "")
    $host.ui.RawUI.WindowTitle = "B2C $TenantShort - $user"
    
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
                   
        write-host "Config File    :`t$ConfigPath"
        write-host "B2C Tenant     :`t$tenantID, $tenantName"
        write-host "B2C Client Cred:`t$($env:B2CAppId), $($app.DisplayName)"
    }    
    $authHeader = Connect-AzADB2CClientCredentials -Scope "https://graph.microsoft.com/.default"    
}

<#
.SYNOPSIS
    Downloads the Azure AD B2C Starer Pack

.DESCRIPTION
    Downloads the Azure AD B2C Custom Policy Starter Pack from https://github.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack

.PARAMETER PolicyPath
    Path to store the downloades files. Current Directory is default

.PARAMETER PolicyType
    The type of policies to download. SocialAndLocalAccounts is default

.PARAMETER PolicyFile
    Filename if only downloading a single file. 

.EXAMPLE
    Get-AzADB2CStarterPack -PolicyType "SocialAndLocalAccountsWithMfa"
#>
function Get-AzADB2CStarterPack(
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('t')][string]$PolicyType = "SocialAndLocalAccounts",
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
        [xml]$tfe = Get-Content "$PolicyPath\TrustFrameworkExtensions.xml"
        if ( $tfe.TrustFrameworkPolicy.BasePolicy.PolicyId -ne "B2C_1A_TrustFrameworkBase" ) {
            $filename = $tfe.TrustFrameworkPolicy.BasePolicy.PolicyId.Replace("B2C_1A_", "")
            DownloadFile "$urlStarterPackBase/$PolicyType/$filename.xml" $PolicyPath
        }
    }
}

<#
.SYNOPSIS
    Starts a new B2C Custom Policies project

.DESCRIPTION
    Wrapper command that downloads the starter pack, auto-edit the details, prepares custom attributes, upgrades to lates html page versions and enables javascript and sets the AppInsight Instrumentation Key.

.PARAMETER TenantName
    TenantName to use for auto-editing the policy files.

.PARAMETER PolicyPath
    Path to store the downloades files. Current Directory is default

.PARAMETER PolicyType
    The type of policies to download. SocialAndLocalAccounts is default

.PARAMETER PolicyPrefix
    Prefix to insert in the PolicyIds, so that B2C_1A_TrustFrameworkExtensions becomes B2C_1A_<prefix>_TrustFrameworkExtensions

.EXAMPLE
    New-AzADB2CPolicyProject -PolicyPrefix "demo"

.EXAMPLE
    New-AzADB2CPolicyProject -PolicyPrefix "demo" -PolicyType "SocialAndLocalWithMfa"

.EXAMPLE
    New-AzADB2CPolicyProject -PolicyPrefix "demo" -PolicyType "SocialAndLocalWithMfa" -NoCustomAttributes:$True
#>
function New-AzADB2CPolicyProject
(
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('b')][string]$PolicyType = "SocialAndLocalAccounts",
    [Parameter(Mandatory=$false)][Alias('x')][string]$PolicyPrefix = "",
    [Parameter(Mandatory=$false)][switch]$NoCustomAttributes = $False
    )
{
    Get-AzADB2CStarterPack -PolicyPath $PolicyPath -PolicyType $PolicyType
    Set-AzADB2CPolicyDetails -TenantName $TenantName -PolicyPath $PolicyPath -PolicyPrefix $PolicyPrefix
    if ( $False -eq $NoCustomAttributes) {
        Set-AzADB2CCustomAttributeApp -PolicyPath $PolicyPath
    }
    Set-AzADB2CAppInsights -PolicyPath $PolicyPath
    Set-AzADB2CCustomizeUX -PolicyPath $PolicyPath
}

<#
.SYNOPSIS
    Auto-edit policy file details

.DESCRIPTION
    Updates the policy file details to make them ready for upload to a specific tenant

.PARAMETER TenantName
    TenantName to use for auto-editing the policy files.

.PARAMETER PolicyPath
    Path to store the downloades files. Current Directory is default

.PARAMETER PolicyType
    The type of policies to download. SocialAndLocalAccounts is default

.PARAMETER PolicyPrefix
    Prefix to insert in the PolicyIds, so that B2C_1A_TrustFrameworkExtensions becomes B2C_1A_<prefix>_TrustFrameworkExtensions

.PARAMETER IefAppName
    Name of IdentityExperienceFramework app. Default is IdentityExperienceFramework

.PARAMETER IefProxyAppName
    Name of ProxyIdentityExperienceFramework app. Default is ProxyIdentityExperienceFramework

.PARAMETER ExtAppDisplayName
    Name of the App to use for extension attributes. The default is the b2c-extensions-app

.PARAMETER Clean
    Cleans the policy files and prepares them for sharing

.EXAMPLE
    Set-AzADB2CPolicyDetails -PolicyPrefix "demo"

.EXAMPLE
    Set-AzADB2CPolicyDetails -PolicyPrefix "demo" -ExtAppDisplayName "ext-app-name"

.EXAMPLE
    Set-AzADB2CPolicyDetails -Clean
#>
function Set-AzADB2CPolicyDetails
(
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('f')][string]$PolicyFile = "",
    [Parameter(Mandatory=$false)][Alias('x')][string]$PolicyPrefix = "",
    [Parameter(Mandatory=$false)][string]$IefAppName = "",
    [Parameter(Mandatory=$false)][string]$IefProxyAppName = "",    
    [Parameter(Mandatory=$false)][string]$ExtAppDisplayName = "b2c-extensions-app",     # name of add for b2c extension attributes
    [Parameter(Mandatory=$false)][switch]$Clean = $False            # if to "clean" the policies and revert to "yourtenant.onmicrosoft.com" etc
    )
{

    if ( $True -eq $Clean ) {
        $TenantName = "yourtenant.onmicrosoft.com"
        $IefAppName = "IdentityExperienceFramework"
        $IefProxyAppName = "ProxyIdentityExperienceFramework"
        write-host "Making Policies generic for sharing"
    } else {
        if ( "" -eq $TenantName ) { $TenantName = $global:TenantName }
        if ( "" -eq $IefAppName ) { $IefAppName = $global:b2cAppSettings.IefAppName}
        if ( "" -eq $IefAppName ) { $IefAppName = "IdentityExperienceFramework"}
        if ( "" -eq $IefProxyAppName ) { $IefProxyAppName = $global:b2cAppSettings.IefProxyAppName}
        if ( "" -eq $IefProxyAppName ) { $IefProxyAppName = "ProxyIdentityExperienceFramework"}
    }

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
                                        $item.InnerText = $AppIdIEFProxy
                                    }
                                    if ( "IdTokenAudience" -eq $item.Key ) {
                                        $item.InnerText = $AppIdIEF
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
                                            $item.InnerText = "...add your client_id here..."
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
                                            $item.InnerText = $appExtAppId
                                        }
                                        if ( "ApplicationObjectId" -eq $item.Key ) {
                                            $item.InnerText = $appExtObjectId
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
        RefreshTokenIfExpired

        $tenantID = Get-TenantIdFromName -TenantName $TenantName
        <##>
        if ( "" -eq $tenantID ) {
            write-host "Unknown Tenant"
            return
        }
        write-host "Tenant:  `t$tenantName`nTenantID:`t$tenantId"

        write-host "Getting AppID's for $IefAppName"
        #$resp = Invoke-GraphRestMethodGet "applications?`$filter=displayName eq '$iefAppName'&`$select=id,appid"
        $resp = Get-Application -DisplayName $iefAppName -Select "id,appid"
        $appIdIEF = $resp.value[0].appid
        write-host "AppId:`t$appIdIEF"

        write-host "Getting AppID's for $IefProxyAppName"
        #$resp = Invoke-GraphRestMethodGet "applications?`$filter=displayName eq '$iefProxyAppName'&`$select=id,appid"
        $resp = Get-Application -DisplayName $iefProxyAppName -Select "id,appid"
        $AppIdIEFProxy = $resp.value[0].appid
        write-host "AppId:`t$AppIdIEFProxy"

        if ( "" -ne $ExtAppDisplayName ) {    
            write-host "Getting AppID's for $ExtAppDisplayName"
            #$resp = Invoke-GraphRestMethodGet "applications?`$filter=startswith(displayName,'$ExtAppDisplayName')&`$select=id,appid"
            $resp = Get-Application -DisplayNameStartsWith $ExtAppDisplayName -Select "id,appid"
            $appExtAppId = $resp.value[0].appid
            $appExtObjectId = $resp.value[0].id
            write-host "ObjectID:`t$appExtObjectId`nAppId:`t$appExtAppId"
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
} # fn

<#
.SYNOPSIS
    Gets a B2C Custom Policy 

.DESCRIPTION
    Gets a B2C Custom Policy from the tenant policy store by PolicyId

.PARAMETER TenantName
    TenantName to use for auto-editing the policy files.

.PARAMETER PolicyId
    PolicyId in the B2C tenant

.PARAMETER PolicyFile
    Filename to store policy in

.PARAMETER AppID
    AppID for your client_credentials. Default is to use $env:B2CAppID

.PARAMETER AppKey
    secret for your client_credentials. Default is to use $env:B2CAppKey

.EXAMPLE
    Get-AzADB2CPolicy -PolicyId "B2C_1A_demo_TrustFrameworkExtensions"
#>
function Get-AzADB2CPolicy
(
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyId = "",
    [Parameter(Mandatory=$false)][Alias('f')][string]$PolicyFile = ""
    )
{
    RefreshTokenIfExpired
    $resp = Invoke-GraphRestMethodGet "trustFramework/policies/$PolicyId/`$value" -ContentType "application/xml"
    if ( "" -eq $PolicyFile ) {
        return $resp.OuterXml
    } else {
        Set-Content -Path $PolicyFile -Value $resp.OuterXml 
    }
}

<#
.SYNOPSIS
    Lists B2C Custom Policies

.DESCRIPTION
    Lists B2C Custom Policies from the tenant policy

.PARAMETER TenantName
    TenantName to use for auto-editing the policy files.

.PARAMETER PolicyId
    PolicyId in the B2C tenant

.PARAMETER AppID
    AppID for your client_credentials. Default is to use $env:B2CAppID

.PARAMETER AppKey
    secret for your client_credentials. Default is to use $env:B2CAppKey

.EXAMPLE
    List-AzADB2CPolicyId
#>
function Get-AzADB2CPolicyIds()
{
    RefreshTokenIfExpired
    $resp = Invoke-GraphRestMethodGet "trustFramework/policies" -ContentType "application/xml"
    $resp.value | ConvertTo-json
}

<#
.SYNOPSIS
    Uploads B2C Custom Policies 

.DESCRIPTION
    Uploads B2C Custom Policies from local path to B2C tenant

.PARAMETER TenantName
    TenantName to use for auto-editing the policy files.

.PARAMETER PolicyPath
    Path to policies. Default is current directory

.PARAMETER PolicyFile
    Policy filename if uploading specific file. Default is all policy files in PolicyPath

.PARAMETER AppID
    AppID for your client_credentials. Default is to use $env:B2CAppID

.PARAMETER AppKey
    secret for your client_credentials. Default is to use $env:B2CAppKey

.EXAMPLE
    Import-AzADB2CPolicyToTenant

.EXAMPLE
    Import-AzADB2CPolicyToTenant -PolicyFile ".\SignUpOrSignin.xml"
#>
function Import-AzADB2CPolicyToTenant
(
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('f')][string]$PolicyFile = ""
)
{    
    # enumerate all XML files in the specified folders and create a array of objects with info we need
    Function EnumPoliciesFromPath( [string]$PolicyPath ) {
        $files = get-childitem -path $policypath -name -include *.xml | Where-Object {! $_.PSIsContainer }
        $arr = @()
        foreach( $file in $files ) {
            #write-host "Reading Policy XML file $file..."
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
                $policy | Add-Member -type NoteProperty -name "HasChildren" -Value $null
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
                write-host "$($p.PolicyId) has wrong tenant configured $($p.xml.TrustFrameworkPolicy.TenantId) - skipped"
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
        try {
            $resp = Invoke-GraphRestMethodPut "trustFramework/policies/$PolicyId/`$value" -Body $PolicyData -ContentType "application/xml"
            write-host $resp.TrustFrameworkPolicy.PublicPolicyUri
        } catch {
            $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $streamReader.BaseStream.Position = 0
            $streamReader.DiscardBufferedData()
            $errResp = $streamReader.ReadToEnd()
            $streamReader.Close()    
            write-host $errResp -ForegroundColor "Red" -BackgroundColor "Black"
        }
    }
    
    RefreshTokenIfExpired

    if ( "" -eq $PolicyPath ) {
        $PolicyPath = (get-location).Path
    }
    
    if ( "" -ne $PolicyFile ) {
        # upload a single file
        $PolicyData = Get-Content $PolicyFile # 
        [xml]$xml = $PolicyData
        UploadPolicy $xml.TrustFrameworkPolicy.PolicyId $PolicyData
    } else {
        # load the XML Policy files
        $arr = EnumPoliciesFromPath $PolicyPath
        # find out who is/are the root in inheritance chain so we know which to upload first
        foreach( $p in $arr ) {
            $p.HasChildren = ( $null -ne ($arr | where {$_.PolicyId -eq $p.BasePolicyId}) ) 
        }
        # upload policies - start with those who are root(s)
        foreach( $p in $arr ) {
            if ( $p.HasChildren -eq $False ) {
                ProcessPolicies $arr $p.BasePolicyId
            }
        }
        # check what hasn't been uploaded
        foreach( $p in $arr ) {
            if ( $p.Uploaded -eq $false ) {
                write-host "$($p.PolicyId) has a refence to $($p.BasePolicyId) which doesn't exists in the folder - not uploaded"
            }
        }
    }   
}

<#
.SYNOPSIS
    Sets the B2C extension attributes app

.DESCRIPTION
    Sets the AppID and objectId for extension attributes in the B2C Custom Policies

.PARAMETER TenantName
    TenantName to use for auto-editing the policy files.

.PARAMETER PolicyPath
    Path to policies. Default is current directory

.PARAMETER PolicyFile
    Filename of TrustFrameworkExtensions.xml if it has a non-default name.

.PARAMETER client_id
    AppID for the app that handles extension attributes for your policy

.PARAMETER object_id
    objectID for the app that handles extension attributes for your policy

.PARAMETER AppDisplayName
    If you name the app to handle the extension attributes, the command will get the client_id and objectId for that app.

.EXAMPLE
    Set-AzADB2CCustomAttributeApp

.EXAMPLE
    Set-AzADB2CCustomAttributeApp -AppDisplayName "my-ext-app"
#>
function Set-AzADB2CCustomAttributeApp
(
        [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",    
        [Parameter(Mandatory=$false)][Alias('c')][string]$client_id = "",    # client_id/AppId of the app handeling custom attributes
        [Parameter(Mandatory=$false)][Alias('a')][string]$objectId = "",     # objectId of the same app
        [Parameter(Mandatory=$false)][Alias('n')][string]$AppDisplayName = "",     # objectId of the same app
        [Parameter(Mandatory=$false)][Alias('f')][string]$PolicyFile = "TrustFrameworkExtensions.xml"     # if the Extensions file has a different name
)
{    
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
      write-host "TechnicalProfileId $tpId already exists in policy"
      return
    }
    
    RefreshTokenIfExpired

    # if no client_id given, use the standard b2c-extensions-app
    if ( "" -eq $client_id ) {
        if ( "" -eq $AppDisplayName ) { $AppDisplayName = "b2c-extensions-app"}
        write-host "Using $AppDisplayName"
        #$appExt = Invoke-GraphRestMethodGet "applications?`$filter=startswith(displayName,'$AppDisplayName')&`$select=id,appid"
        $appExt = Get-Application -DisplayNameStartsWith $AppDisplayName -Select "id,appid"
        $client_id = $appExt.value[0].appid
        $objectId = $appExt.value[0].id
    }
    write-host "Adding TechnicalProfileId $tpId"    
    $claimsProviderXml = $claimsProviderXml.Replace("{client_id}", $client_id)
    $claimsProviderXml = $claimsProviderXml.Replace("{objectId}", $objectId)    
    $ext.TrustFrameworkPolicy.ClaimsProviders.innerXml = $ext.TrustFrameworkPolicy.ClaimsProviders.innerXml + $claimsProviderXml    
    $ext.Save("$PolicyPath/$PolicyFile")    
}

<#
.SYNOPSIS
    Prepares the policies for UX customizations

.DESCRIPTION
    Prepares the policies for UX customizations via setting page version to latest and enabling javascript

.PARAMETER PolicyPath
    Path to policies. Default is current directory

.PARAMETER RelyingPartyFileName
    Name of Replying Party file. Default is SignupOrSignin.xml

.PARAMETER ExtPolicyFileName
    Name of TrustFrameworkExtensions file. Default is TrustFrameworkExtensions.xml

.PARAMETER BasePolicyFileName
    Name of TrustFrameworBase file. Default is TrustFrameworkBase.xml

.PARAMETER DownloadHtmlTemplates
    If to download the standard html templates to local directory

.PARAMETER HtmlFolderName
    Local folder name for downloading html files. Default is "html"

.EXAMPLE
    Set-AzADB2CCustomizeUX

.EXAMPLE
    Set-AzADB2CCustomizeUX -FullContentDefinition:$True

.EXAMPLE
    Set-AzADB2CCustomizeUX -DownloadHtmlTemplates 
#>
function Set-AzADB2CCustomizeUX
(
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",    
    [Parameter(Mandatory=$false)][Alias('r')][string]$RelyingPartyFileName = "SignUpOrSignin.xml",
    [Parameter(Mandatory=$false)][Alias('b')][string]$BasePolicyFileName = "TrustFrameworkBase.xml",
    [Parameter(Mandatory=$false)][Alias('e')][string]$ExtPolicyFileName = "TrustFrameworkExtensions.xml",
    [Parameter(Mandatory=$false)][Alias('d')][switch]$DownloadHtmlTemplates = $false,    
    [Parameter(Mandatory=$false)][Alias('h')][string]$HtmlFolderName = "html",    
    [Parameter(Mandatory=$false)][Alias('u')][string]$urlBaseUx = "",
    [Parameter(Mandatory=$false)][switch]$FullContentDefinition = $False
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
    RefreshTokenIfExpired

    [xml]$ext =Get-Content -Path "$PolicyPath\$ExtPolicyFileName" -Raw
    if ((Test-Path -Path "$PolicyPath/$BasePolicyFileName" -PathType Leaf) -eq $True ) {
        [xml]$base = Get-Content -Path "$PolicyPath/$BasePolicyFileName" -Raw
    } else {
        [xml]$base = Get-AzADB2CPolicyId -PolicyId $ext.TrustFrameworkPolicy.BasePolicy.PolicyId
    }
    
    $tenantShortName = $base.TrustFrameworkPolicy.TenantId.Split(".")[0]
    $cdefs = $base.TrustFrameworkPolicy.BuildingBlocks.ContentDefinitions.Clone()
    
    if ( $true -eq $DownloadHtmlTemplates) {    
        $ret = New-Item -Path $PolicyPath -Name "$HtmlFolderName" -ItemType "directory" -ErrorAction SilentlyContinue
    }
    <##>
    foreach( $contDef in $cdefs.ContentDefinition ) {    
        switch( $contDef.DataUri ) {        
            "urn:com:microsoft:aad:b2c:elements:globalexception:1.0.0" { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:globalexception:1.2.1" } 
            "urn:com:microsoft:aad:b2c:elements:globalexception:1.1.0" { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:globalexception:1.2.1" }
            "urn:com:microsoft:aad:b2c:elements:idpselection:1.0.0"    { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:providerselection:1.2.1" }
            "urn:com:microsoft:aad:b2c:elements:multifactor:1.0.0"     { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:multifactor:1.2.5" }
            "urn:com:microsoft:aad:b2c:elements:multifactor:1.1.0"     { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:multifactor:1.2.5" }
    
            "urn:com:microsoft:aad:b2c:elements:unifiedssd:1.0.0"    { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:unifiedssd:2.1.5" } 
            "urn:com:microsoft:aad:b2c:elements:unifiedssp:1.0.0"    { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:unifiedssp:2.1.5" } 
    
            "urn:com:microsoft:aad:b2c:elements:selfasserted:1.0.0"    { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:selfasserted:2.1.7" } 
            "urn:com:microsoft:aad:b2c:elements:selfasserted:1.1.0"    { $contDef.DataUri = "urn:com:microsoft:aad:b2c:elements:contract:selfasserted:2.1.7" }
        }  

        if ( $False -eq $FullContentDefinition ) {
            $i1 = $contDef.InnerXml.IndexOf("<RecoveryUri" )
            $i2 = $contDef.InnerXml.IndexOf("</RecoveryUri>" )
            if ( $i2 -gt $i1 ) {
                $contDef.InnerXml = $contDef.InnerXml.SubString(0,$i1) + $contDef.InnerXml.SubString($i2+"</RecoveryUri>".Length) 
            }
            $i1 = $contDef.InnerXml.IndexOf("<LoadUri" )
            $i2 = $contDef.InnerXml.IndexOf("</LoadUri>" )
            if ( $i2 -gt $i1 ) {
                $contDef.InnerXml = $contDef.InnerXml.SubString(0,$i1) + $contDef.InnerXml.SubString($i2+"</LoadUri>".Length) 
            }
            $contDef.RemoveChild( $contDef.Metadata ) | Out-null
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

<#
.SYNOPSIS
    Runs a B2C Custom Policy

.DESCRIPTION
    Creates a working url for testing and launches a browser to test a B2C Custom Policy

.PARAMETER PolicyFile
    Policy to run

.PARAMETER WebAppName
    Name of WebApp to use as client_id.

.PARAMETER redirect_uri
    The redirect_uri of the request. Default is https://jwt.ms

.PARAMETER response_types
    response_types for the request. Default is "id_token"

.PARAMETER scopes
    Scopes for the request. Default is "openid"

.PARAMETER Chrome
    Use the Chrome browser. Default is your default browser

.PARAMETER Edge
    Use the Edge browser. Default is your default browser

.PARAMETER Firefox
    Use the Firefox browser. Default is your default browser

.PARAMETER Incognito
    Start the browser in incognito/inprivate mode (default). Specify -Incognito:$False to disable

.PARAMETER NewWindow
    Start the browser in a new window (default). Specify -NewWindow:$False to disable

.PARAMETER QueryString
    Extra QueryString to add, for instance "&login_hint=alice@contoso.com"

.PARAMETER Prompt
    What prompt to use. Default is "login". Accepted values are none, login and not specified

.EXAMPLE
    Test-AzADB2CPolicy -n "ABC-WebApp" -p ".\SignUpOrSignin.xml"

.EXAMPLE
    Test-AzADB2CPolicy -n "ABC-WebApp" -p ".\SignUpOrSignin.xml" -Firefox

.EXAMPLE
    Test-AzADB2CPolicy -n "ABC-WebApp" -p ".\SignUpOrSignin.xml" -Firefox -Incognito:$False -NewWindow:$False
#>
function Test-AzADB2CPolicy
(
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyFile,
    [Parameter(Mandatory=$false)][Alias('i')][string]$PolicyId,
    [Parameter(Mandatory=$false)][Alias('n')][string]$WebAppName = "",
    [Parameter(Mandatory=$false)][Alias('r')][string]$redirect_uri = "https://jwt.ms",
    [Parameter(Mandatory=$false)][Alias('s')][string]$scopes = "",
    [Parameter(Mandatory=$false)][Alias('t')][string]$response_type = "id_token",
    [Parameter(Mandatory=$false)][Alias('b')][string]$browser = "", # Chrome, Edge or Firefox
    [Parameter(Mandatory=$false)][Alias('q')][string]$QueryString = "", # extra querystring params
    [Parameter(Mandatory=$false)][string]$Prompt = "login", 
    [Parameter(Mandatory=$false)][switch]$Chrome = $False,
    [Parameter(Mandatory=$false)][switch]$Edge = $False,
    [Parameter(Mandatory=$false)][switch]$Firefox = $False,
    [Parameter(Mandatory=$false)][switch]$Incognito = $True,
    [Parameter(Mandatory=$false)][switch]$NewWindow = $True,
    [Parameter(Mandatory=$false)][switch]$Metadata = $False,
    [Parameter(Mandatory=$false)][switch]$SAMLIDP = $False
)
{
    $isSAML = $false
    $tenantName = $global:TenantName
    if ( "" -eq $PolicyId ) {
        if (!(Test-Path $PolicyFile -PathType leaf)) {
            write-error "File does not exists: $PolicyFile"
            return
        }
        [xml]$xml = Get-Content $PolicyFile
        $PolicyId = $xml.TrustFrameworkPolicy.PolicyId
        if ( "" -eq $tenantName ) {
            $tenantName = $xml.TrustFrameworkPolicy.TenantId
        }

        if ( "SAML2"-ne $xml.TrustFrameworkPolicy.RelyingParty.TechnicalProfile.Protocol.Name ) {
            $isSAML = $false
        } else {
            $isSAML = $true
        }
    }

    if ( "" -eq $WebAppName ) {
        if ( $isSAML ) {
            $WebAppName = $global:b2cAppSettings.SAMLTestAppName
        } else {
            $WebAppName = $global:b2cAppSettings.TestAppName
        }
    }
    
    if ( $QueryString.length -gt 0 -and $QueryString.StartsWith("&") -eq $False ) {
        $QueryString = "&$QueryString"
    }

    $hostName = "{0}.b2clogin.com" -f $tenantName.Split(".")[0]    
    if ( $global:B2CCustomDomain.Length -gt 0) {
        $hostName = $global:B2CCustomDomain
        write-host "Using B2C Custom Domain" $global:B2CCustomDomain        
    }

    RefreshTokenIfExpired

    write-host "Getting test app $WebAppName"
    #$app = Invoke-GraphRestMethodGet "applications?`$filter=startswith(displayName,'$WebAppName')"    
    $app = Get-Application -DisplayNameStartsWith $WebAppName
    if ( $app.value.Length -eq 0 ) {
        write-error "App name isn't registered: $WebAppName"
        return
    }
    if ( $app.value.Length -gt 1 ) {
        $app = $app.value | where {$_.DisplayName -eq $WebAppName}
    } else {
        $app = $app.value[0]
    }

    $pgm, $params = Get-BrowserInfo -Chrome $Chrome -Edge $Edge -Firefox $Firefox -Incognito $Incognito -NewWindow $NewWindow

    if ( $isSAML) {
        #$sp = Invoke-GraphRestMethodGet "servicePrincipals?`$filter=appid eq '$($app.appid)'"   
        $sp = Get-ServicePrincipal $app.appid 
        $sp = $sp.value | where {$_.appid -eq $app.appid}
        if ( 0 -eq $sp.SamlMetadataUrl.Length ) {
            write-error "App has no SamlMetadataUrl set: $WebAppName"
            return
        }
        if ( $app.identifierUris.Count -gt 1 ) {
            $Issuer = ($app.identifierUris | where { $_ -imatch $hostName })
            if ( $null -eq $Issuer) { $Issuer = ($app.identifierUris | where { $_ -imatch $tenantName })}
        } else {
            $Issuer = $app.identifierUris[0]
        }

        if ( $Metadata ) {
            $url = "https://{0}/{1}/{2}/samlp/metadata" -f  $hostName, $tenantName, $PolicyId
        } else {
            if ( $SAMLIDP ) {
                $url = "https://{0}/{1}/{2}/generic/login?EntityId={3}" -f  $hostName, $tenantName, $PolicyId, $Issuer
            } else {
                $url = "https://samltestapp4.azurewebsites.net/SP?Tenant={0}&Policy={1}&Issuer={2}&HostName={3}" -f $tenantName, $PolicyId, $Issuer, $hostName
            }
        }
    } else {
        $scope = "openid"
        # if extra scopes passed on cmdline, then we will also ask for an access_token
        if ( "" -ne $scopes ) {
            $scope = "openid offline_access $scopes"
            $response_type = "$response_type token"
        }
        if ( $Prompt.Length -gt 0 ) {
            $Prompt = "&prompt=" + $Prompt
        } else {
            $Prompt = "" 
        }
        $qparams = "client_id={0}&nonce={1}&redirect_uri={2}&scope={3}&response_type={4}{5}&disable_cache=true" `
                    -f $app.appid, (New-Guid).Guid, $redirect_uri, $scope, $response_type, $Prompt
        # Q&D urlencode
        $qparams = $qparams.Replace(":","%3A").Replace("/","%2F").Replace(" ", "%20") + $QueryString
    
        if ( $Metadata ) {
            $url = "https://{0}/{1}/{2}/v2.0/.well-known/openid-configuration" -f $hostName, $tenantName, $PolicyId
        } else {
            $url = "https://{0}/{1}/{2}/oauth2/v2.0/authorize?{3}" -f $hostName, $tenantName, $PolicyId, $qparams
        }
    }
    
    write-host "Starting Browser`n$url"
    Start-Browser -pgm $pgm -params $params -url $url        
}

<#
.SYNOPSIS
    Deletes B2C Custom Policies from a B2C tenant

.DESCRIPTION
    Enumerates files in PolicyPath and deletes one or more B2C Custom Policies from a B2C tenant. 

.PARAMETER PolicyPath
    Path to local files to who's PolicyId should be deleted from the B2C tenant. Default is all policies in the current directory

.PARAMETER PolicyFile
    Policy to delete. Default is all policies in the current directory

.PARAMETER PolicyId
    PolicyId to delete in the B2C tenant

.PARAMETER TenantName
    B2C Tenant name to use.

.PARAMETER AppID
    AppID for your client_credentials. Default is to use $env:B2CAppID

.PARAMETER AppKey
    secret for your client_credentials. Default is to use $env:B2CAppKey

.EXAMPLE
    Remove-AzADB2CPolicyFromTenant

.EXAMPLE
    Remove-AzADB2CPolicyFromTenant -f ".\SignUpOrSignin.xml"
#>
function Remove-AzADB2CPolicyFromTenant
(
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('f')][string]$PolicyFile = "",
    [Parameter(Mandatory=$false)][Alias('i')][string]$PolicyId = ""
)
{    
    RefreshTokenIfExpired
    # invoke the Graph REST API to upload the Policy
    Function DeletePolicy( [string]$PolicyId) {
        # https://docs.microsoft.com/en-us/graph/api/trustframework-put-trustframeworkpolicy?view=graph-rest-beta
        # Delete the Custom Policy
        write-host "Deleteing policy $PolicyId..."
        $resp = Invoke-GraphRestMethodDelete "trustFramework/policies/$PolicyId"
    }    
    if ( "" -eq $PolicyPath ) {
        $PolicyPath = (get-location).Path
    }
    if ( "" -ne $PolicyId ) {
        DeletePolicy $PolicyId
    } elseif ( "" -ne $PolicyFile ) {
        $PolicyData = Get-Content $PolicyFile # 
        [xml]$xml = $PolicyData
        DeletePolicy $xml.TrustFrameworkPolicy.PolicyId
    } else {
        $files = get-childitem -path $PolicyPath -name -include *.xml | Where-Object {! $_.PSIsContainer }
        foreach( $file in $files ) {
            #write-host "Reading Policy XML file $file..."
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

<#
.SYNOPSIS
    Sets the AppInsign InstrumentationKey

.DESCRIPTION
    Sets the AppInsign InstrumentationKey in all or one RelyingParty files in PolicyPath

.PARAMETER PolicyFile
    Policy to update. Default is all policies in the current directory

.PARAMETER PolicyPath
    PolicyPath to use. Default is current directory

.PARAMETER InstrumentationKey
    AppInsight InstrumentationKey

.EXAMPLE
    Set-AzADB2CAppInsights

.EXAMPLE
    Set-AzADB2CAppInsights -InstrumentationKey "280f8d4e-26a4-4d4e-9327-4b76d52ab8e9"
#>
function Set-AzADB2CAppInsights
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
            #write-host "Reading Policy XML file $file..."
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
            write-host "Adding AppInsights InstrumentationKey $InstrumentationKey to $($xml.TrustFrameworkPolicy.PolicyId)"
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

<#
.SYNOPSIS
    Loads B2C configuration

.DESCRIPTION
    Loads B2C configuration from file b2cAppSetings_yourtenant.json

.PARAMETER ConfigPath
    ConfigPath to config file

.PARAMETER TenantName
    Tenant to connect to. If not specified, tenant name must exist in ConfigPath

.PARAMETER PolicyPath
    Path to config file. Default is current directory

.PARAMETER PolicyPrefix
    PolicyPrefix to load. Prefix is "demo" in B2C_1A_demo_SignUpOrSignin

.EXAMPLE
    Read-AzADB2CConfig -ConfigPath .\b2cAppSettings_yourtenant.json
#>
function Read-AzADB2CConfig
(
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('n')][string]$PolicyPrefix = "",  
    [Parameter(Mandatory=$false)][Alias('k')][boolean]$KeepPolicyIds = $False,  
    [Parameter(Mandatory=$true)][Alias('c')][string]$ConfigPath = ""
    )
{
    
    if ( !(Test-Path $ConfigPath -PathType Leaf) ) {
        write-error "Config file not found $ConfigPath"
        return
    }

    $tenantName = $global:tenantName
    $tenantID = $global:tenantID

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
    if ( "" -eq $b2cAppSettings.TenantName ) {
        $TenantName = $b2cAppSettings.TenantName
    }    
    $global:tenantName = $tenantName
    $global:tenantID = $tenantID
    
    write-host "Config File    :`t$ConfigPath"
    write-host "B2C Tenant     :`t$tenantID, $tenantName"
    write-host "B2C Client Cred:`t$($env:B2CAppId), $($app.DisplayName)"
    write-host "Policy Prefix  :`t$PolicyPrefix"        
}

<#
.SYNOPSIS
    Adds a ClaimsProvider

.DESCRIPTION
    Adds a ClaimsProvider configuration to the TrustFrameworkExtensions.xml file

.PARAMETER PolicyPath
    Path to policy files. Default is current directory

.PARAMETER ProviderName
    Name of provider to add. Must be Google, Twitter, Amazon, LinkedId, AzureAD, MSA or Facebook. For AzureAD, AadtenantName must be defined

.PARAMETER client_id
    client_id of the registered app in its respecive environment

.PARAMETER AadTenantName
    Name of AAD tenant in the ClaimsProvider definition for TechnicalProfileId. It will be given the name "{AadtenantName}-OIDC"

.PARAMETER BasePolicyFileName
    Name of base configuration file. Default is TrustFrameworkBase.xml

.PARAMETER ExtPolicyFileName
    Name of extension configuration file. Default is TrustFrameworkExtensions.xml

.EXAMPLE
    Add-AzADB2CClaimsProvider -ProviderName "Google"

.EXAMPLE
    Add-AzADB2CClaimsProvider -ProviderName "AzureAD" -AadTenantName "contoso.com"

.EXAMPLE
    Add-AzADB2CClaimsProvider -ProviderName "RESTAPI"
#>
function Add-AzADB2CClaimsProvider (
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",    
    [Parameter(Mandatory=$true)][Alias('i')][string]$ProviderName = "",    # google, twitter, amazon, linkedid, AzureAD, restapi
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
    RefreshTokenIfExpired
    [xml]$ext =Get-Content -Path "$PolicyPath/$ExtPolicyFileName" -Raw
    if ((Test-Path -Path "$PolicyPath/$BasePolicyFileName" -PathType Leaf) -eq $True ) {
        [xml]$base = Get-Content -Path "$PolicyPath/$BasePolicyFileName" -Raw
    } else {
        [xml]$base = Get-AzADB2CPolicyId -PolicyId $ext.TrustFrameworkPolicy.BasePolicy.PolicyId
    }

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

$restapiCP = @"
    <ClaimsProvider>
      <DisplayName>REST API</DisplayName>
      <TechnicalProfiles>
        <TechnicalProfile Id="{tpId}">
          <DisplayName>Describe the purpose of your REST API here</DisplayName>
          <Protocol Name="Proprietary" Handler="Web.TPEngine.Providers.RestfulProvider, Web.TPEngine, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null" />
          <Metadata>
            <Item Key="ServiceUrl">https://yourname.azurewebsites.net/api/yourfuncname?code=...</Item>
            <Item Key="AuthenticationType">None</Item>
            <Item Key="SendClaimsIn">Body</Item>
            <Item Key="AllowInsecureAuthInProduction">true</Item>
          </Metadata>
          <InputClaims>
            <!-- modify this to pass whatever claims you need -->
            <InputClaim ClaimTypeReferenceId="signInName" PartnerClaimType="username" />
            <InputClaim ClaimTypeReferenceId="objectId"  />
          </InputClaims>
          <OutputClaims>
            <!-- modify this to capture any return claims from the function-->
            <OutputClaim ClaimTypeReferenceId="groups" />
          </OutputClaims>
          <UseTechnicalProfileForSessionManagement ReferenceId="SM-Noop" />
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
        "restapi" { $tpId = "REST-API-Yourname"; $claimsExchangeId=""; $claimsProviderXml = $restapiCP }
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
        default { write-error "IdP name must be either or google, twitter, linkedin, amazon, facebook, azuread, msa or restapi"; return }
    }

    if ( $ext.TrustFrameworkPolicy.ClaimsProviders.InnerXml -imatch $tpId ) {
        if ( "Facebook-OAUTH" -eq $tpId) {
            write-host "Updating TechnicalProfileId $tpId"
            $ext.TrustFrameworkPolicy.InnerXml = $ext.TrustFrameworkPolicy.InnerXml.Replace( "facebook_clientid", $client_id) 
            $ext.Save("$PolicyPath/$ExtPolicyFileName")        
            return
        }
        write-warning "TechnicalProfileId $tpId already exists in policy"
        return
    }

    write-host "Adding TechnicalProfileId $tpId"

    $claimsProviderXml = $claimsProviderXml.Replace("{client_id}", $client_id)
    $claimsProviderXml = $claimsProviderXml.Replace("{tpId}", $tpId)
    if ( "azuread" -eq $ProviderName.ToLower() ) {
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

    if ( $claimsExchangeId.length -gt 0 ) {
        $claimsProviderSelection = "<ClaimsProviderSelection TargetClaimsExchangeId=`"$claimsExchangeId`"/>"
        $userJourney.OrchestrationSteps.OrchestrationStep[0].ClaimsProviderSelections.InnerXml = $userJourney.OrchestrationSteps.OrchestrationStep[0].ClaimsProviderSelections.InnerXml + $claimsProviderSelection

        $claimsExchangeTP = "<ClaimsExchange Id=`"$claimsExchangeId`" TechnicalProfileReferenceId=`"$tpId`"/>"
        $userJourney.OrchestrationSteps.OrchestrationStep[1].ClaimsExchanges.InnerXml = $userJourney.OrchestrationSteps.OrchestrationStep[1].ClaimsExchanges.InnerXml + $claimsExchangeTP

        if ( $true -eq $copyFromBase ) {
        try {
            $ext.TrustFrameworkPolicy.InnerXml = $ext.TrustFrameworkPolicy.InnerXml.Replace( "<!--UserJourneys>", "<UserJourneys>" + $userJourney.OuterXml + "</UserJourneys>") 
        } Catch {}
        }
    }

    $ext.TrustFrameworkPolicy.InnerXml = $ext.TrustFrameworkPolicy.InnerXml.Replace( "xmlns=`"`"", "") 
    $ext.Save("$PolicyPath/$ExtPolicyFileName")
}

<#
.SYNOPSIS
    Enables Identity Experience Framework

.DESCRIPTION
    Completes the configuration in the B2C tenant for Identity Experience Framework

.PARAMETER TestAppDisplayName
    Name of test webapp to register that can be used for testing B2C Custom POlicies. It will redirecto jwt.ms

.PARAMETER FacebookSecret
    Dummy Facebook secret to register so that Starter Pack based on social can work directly

.EXAMPLE
    Enable-AzADB2CIdentityExperienceFramework

.EXAMPLE
    Enable-AzADB2CIdentityExperienceFramework -n "ABC-WebApp" -f "abc123"
#>
Function Enable-AzADB2CIdentityExperienceFramework
(
    [Parameter(Mandatory=$false)][Alias('n')][string]$TestAppDisplayName = "Test-WebApp",
    [Parameter(Mandatory=$false)][Alias('f')][string]$FacebookSecret = "abc123"              # dummy fb secret
)
{
    RefreshTokenIfExpired
    New-AzADB2CPolicyKey -KeyContainerName "B2C_1A_TokenSigningKeyContainer" -KeyType "RSA" -KeyUse "sig"
    New-AzADB2CPolicyKey -KeyContainerName "B2C_1A_TokenEncryptionKeyContainer" -KeyType "RSA" -KeyUse "enc"
    New-AzADB2CIdentityExperienceFrameworkApps
    if ( $FacebookSecret.Length -gt 0 ) {
        New-AzADB2CPolicyKey -KeyContainerName "B2C_1A_FacebookSecret" -KeyType "secret" -KeyUse "sig" -Secret $FacebookSecret
    }
    if ( $TestAppDisplayName.Length -gt 0 ) {
        New-AzADB2CTestApp -n $TestAppDisplayName
    }
}

<#
.SYNOPSIS
    Register Identity Experience Framework Apps

.DESCRIPTION
    Register Identity Experience Framework Apps IdentityExperienceFramework and ProxyIdentityExperienceFramework

.PARAMETER DisplayName
    Name of IdentityExperienceFramework App. Default is IdentityExperienceFramework and ProxyIdentityExperienceFramework

.EXAMPLE
    New-AzADB2CIdentityExperienceFrameworkApps

.EXAMPLE
    New-AzADB2CIdentityExperienceFrameworkApps -DisplayName "IEFApp"
#>
function New-AzADB2CIdentityExperienceFrameworkApps
(
    [Parameter(Mandatory=$false)][Alias('n')][string]$DisplayName = "IdentityExperienceFramework"
)
{
    RefreshTokenIfExpired
    $tenantName = $global:tenantName
    $tenantID = $global:tenantID
    write-host "$tenantName`n$tenantId"

    $ProxyDisplayName = "Proxy$DisplayName"

    # check that they don't already exists
    #s$app = Invoke-GraphRestMethodGet "applications?`$filter=displayName eq '$DisplayName')"    
    $app = Get-Application -DisplayName $DisplayName
    if ( $app.value.Count -ge 1 ) {
        write-warning "App already exists $DisplayName - You have already configured Identity Experience Framework for this tenant"
        return
    }

    $req1 = @"
        {
			"resourceAppId": "00000002-0000-0000-c000-000000000000",
			"resourceAccess": [
				{
					"id": "311a71cc-e848-46a1-bdf8-97ff7156d8e6",
					"type": "Scope"
				}
			]
		}
"@
    $scopeId = (New-Guid).Guid.ToString()
    $oauth2PermissionScopes = @"
        {
            "adminConsentDescription": "Allow the application to access IdentityExperienceFramework on behalf of the signed-in user.",
            "adminConsentDisplayName": "Access IdentityExperienceFramework",
            "id": "$scopeId",
            "isEnabled": true,
            "type": "User",
            "userConsentDescription": "Allow the application to access IdentityExperienceFramework on your behalf.",
            "userConsentDisplayName": "Access IdentityExperienceFramework",
            "value": "user_impersonation"
        }    
"@
    $redirectUri = "https://$($global:TenantName.Split(".")[0]).b2clogin.com/$global:TenantName"
    $appIEF = Add-AzADB2CApplication -DisplayName $DisplayName -redirectUris $redirectUri `
        -signInAudience "AzureADMyOrg" -requiredResourceAccess $req1 -oauth2PermissionScopes $oauth2PermissionScopes `
        -WebApp -EnableIdTokenIssuance -EnableAccessTokenIssuance:$False -Grant -SetOwner 

    $req2 = @"
        $req1,
        {
			"resourceAppId": "$($appIEF.appId)",
			"resourceAccess": [
				{
					"id": "$scopeId",
					"type": "Scope"
				}
			]
		}
"@
    $appPIEF = Add-AzADB2CApplication -DisplayName $ProxyDisplayName -redirectUris $redirectUri `
        -signInAudience "AzureADMultipleOrgs" -requiredResourceAccess $req2 `
        -PublicClient -EnableIdTokenIssuance -EnableAccessTokenIssuance:$False -Grant -SetOwner
}

<#
.SYNOPSIS
    Registers a B2C IEF Policy Key

.DESCRIPTION
    Registers a B2C IEF Policy Key

.PARAMETER TenantName
    Name of tenant. Default is one currently connected to

.PARAMETER KeyContainerName
    Name of container

.PARAMETER KeyType
    Type of key. must be "RSA" or "secret"

.PARAMETER KeyUse
    Usage of key. must be "sig" or "enc" for signature or encryption

.PARAMETER secret
    the secret value

.PARAMETER AppID
    AppID for your client_credentials. Default is to use $env:B2CAppID

.PARAMETER AppKey
    secret for your client_credentials. Default is to use $env:B2CAppKey

.EXAMPLE
    New-AzADB2CPolicyKey -KeyContainerName "B2C_1A_TokenSigningKeyContainer" -KeyType "RSA" -KeyUse "sig"

.EXAMPLE
    New-AzADB2CPolicyKey -KeyContainerName "B2C_1A_TokenEncryptionKeyContainer" -KeyType "RSA" -KeyUse "enc"

.EXAMPLE
    New-AzADB2CPolicyKey -KeyContainerName "B2C_1A_FacebookSecret" -KeyType "secret" -KeyUse "sig" -Secret $FacebookSecret

#>
function New-AzADB2CPolicyKey
(
    [Parameter(Mandatory=$true)][Alias('n')][string]$KeyContainerName = "", # [B2C_1A_]Name
    [Parameter(Mandatory=$true)][Alias('y')][string]$KeyType = "secret",    # RSA, secret
    [Parameter(Mandatory=$true)][Alias('u')][string]$KeyUse = "sig",        # sig, enc
    [Parameter(Mandatory=$false)][Alias('s')][string]$Secret = ""           # used when $KeyType==secret
)
{
    RefreshTokenIfExpired
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

    try {
        $resp = Invoke-RestMethod -Method GET -Uri "$GraphEndpoint/trustFramework/keySets/$KeyContainerName" -Headers $global:authHeader -ErrorAction SilentlyContinue
        write-warning "$($resp.id) already has $($resp.keys.Length) keys"
        return
    } catch {
    }
    $body = @"
    {
        "id": "$KeyContainerName"
    }
"@
    $resp = Invoke-RestMethod -Method POST -Uri "$GraphEndpoint/trustFramework/keySets" -Headers $global:authHeader -Body $body -ContentType "application/json" -ErrorAction SilentlyContinue
    <##>
    if ( "secret" -eq $KeyType ) {
        $url = "$GraphEndpoint/trustFramework/keySets/$KeyContainerName/uploadSecret"
        $body = @"
    {
        "use": "$KeyUse",
        "k": "$Secret"
    }
"@
    } 
    if ( "rsa" -eq $KeyType ) {
        $url = "$GraphEndpoint/trustFramework/keySets/$KeyContainerName/generateKey"
        $body = @"
    {
        "use": "$KeyUse",
        "kty": "RSA",
    }
"@
    } 

    $resp = Invoke-RestMethod -Method POST -Uri $url -Headers $authHeader -Body $body -ContentType "application/json"
    write-host "key created: $KeyContainerName"    
}

function Add-AzADB2CApplication
(
    [Parameter(Mandatory=$true)][string]$DisplayName = "",
    [Parameter(Mandatory=$false)][string]$redirectUris = "",
    [Parameter(Mandatory=$false)][string]$requiredResourceAccess = "",
    [Parameter(Mandatory=$false)][string]$oauth2PermissionScopes = "",
    [Parameter(Mandatory=$false)][string]$signInAudience = "AzureADandPersonalMicrosoftAccount",
    [Parameter(Mandatory=$false)][switch]$Grant = $False,
    [Parameter(Mandatory=$false)][switch]$SetOwner = $False,
    [Parameter(Mandatory=$false)][switch]$WebApp = $False,
    [Parameter(Mandatory=$false)][switch]$PublicClient = $False,
    [Parameter(Mandatory=$false)][switch]$EnableIdTokenIssuance = $True,
    [Parameter(Mandatory=$false)][switch]$EnableAccessTokenIssuance = $True,
    [Parameter(Mandatory=$false)][switch]$AccessTokenAcceptedVersionV2 = $false
)
{
    $accessTokenAcceptedVersion = "null"
    if ( $accessTokenAcceptedVersionV2 ) {
        $accessTokenAcceptedVersion = "`"2`""
    }
    $isFallbackPublicClient = "false"
    $redirectUrisPublic = ""
    if ( $PublicClient ) {
        $isFallbackPublicClient = "true"
        $redirectUrisPublic = "`"$redirectUris`""
    }
    $redirectUrisWeb = ""
    if ( $WebApp) {
        $redirectUrisWeb = "`"$redirectUris`""
    }
$body = @"
{
    "identifierUris": [
        "https://$($global:TenantName)/$DisplayName"
    ],
    "displayName": "$DisplayName",
    "signInAudience": "$signInAudience",
    "isFallbackPublicClient": $isFallbackPublicClient,
    "api": {
        "requestedAccessTokenVersion": $accessTokenAcceptedVersion,
        "oauth2PermissionScopes": [
            $oauth2PermissionScopes
        ]
    },
    "passwordCredentials": [],
    "requiredResourceAccess": [
        $requiredResourceAccess
    ],
    "appRoles": [],
    "publicClient": {
        "redirectUris": [
            $redirectUrisPublic
        ]
    },
    "web": {
        "redirectUris": [
            $redirectUrisWeb
        ],
        "implicitGrantSettings": {
            "enableIdTokenIssuance": $($enableIdTokenIssuance.ToString().ToLower()),
            "enableAccessTokenIssuance": $($enableAccessTokenIssuance.ToString().ToLower())
        }
    }
}
"@
    write-host "Creating Application $DisplayName"
    $app = Invoke-GraphRestMethodPost "applications" -Body $body
    write-host "ObjectId:`t$($app.id)`nAppId:`t$($app.AppId)"

$bodySP = @"
{
    "accountEnabled": true,
    "appId": "$($app.appId)",
    "displayName": "$DisplayName",
    "replyUrls": [
        "$redirectUris"
    ],
    "servicePrincipalNames": [
        "$($app.identifierUris[0].ToString())",
        "$($app.appId)"
    ],
    "servicePrincipalType": "Application"
}
"@

    write-host "Creating Service Principle $DisplayName"
    $sp = Invoke-GraphRestMethodPost "serviceprincipals" -Body $bodySP
    write-host "ObjectId:`$($sp.id)"

    if ( $Grant ) {
        $startTime = (get-date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $expiryTime = ((get-date).AddYears(2)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $scope = ""
        foreach( $reqResAccess in $app.RequiredResourceAccess ) { 
            #$resource = Invoke-GraphRestMethodGet "serviceprincipals?`$filter=AppId eq '$($reqResAccess.ResourceAppId)'&select=id,displayName,publishedPermissionScopes"
            $resource = Get-ServicePrincipal $reqResAccess.ResourceAppId -Select "id,displayName,publishedPermissionScopes"
            $ResourceObjectId = $resource.value.Id
            foreach( $ra in $reqResAccess.ResourceAccess ) {
                $scope += ($resource.value[0].publishedPermissionScopes | where {$_.id -eq $ra.Id}).Value + " " 
            }
            $bodyG = @{
                clientId    = $sp.Id
                consentType = "AllPrincipals"
                principalId = $null
                resourceId  = $ResourceObjectId
                scope       = $scope
                startTime   = $startTime
                expiryTime  = $expiryTime 
            }
            write-host "Granting $($resource.value.DisplayName) - $scope to $DisplayName"
            $resp = Invoke-GraphRestMethodPost "oauth2PermissionGrants" -Body $($bodyG | convertto-json)
        }
    }
    # set app owner to current user
    if ( $SetOwner -and $global:userObjectId ) {
        $bodyO = @"
{
    "@odata.id": "https://graph.microsoft.com/beta/directoryObjects/$global:userObjectId"
}
"@
        $url = "https://graph.microsoft.com/beta/applications/$($app.id)/owners/`$ref"
        $resp = Invoke-GraphRestMethodPost "applications/$($app.id)/owners/`$ref" -Body $bodyO
    }
    return $app
}

function Set-AzADB2CApplicationClientSecret
(
    [Parameter(Mandatory=$true)][string]$AppObjectId = "",
    [Parameter(Mandatory=$false)][string]$Name = "Key1",
    [Parameter(Mandatory=$false)][Int]$MonthsValid = 24
)
{
    $startTime = (get-date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $expiryTime = ((get-date).AddMonths($MonthsValid)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $passwordCredentials = @"
    {
        "passwordCredential": {
            "customKeyIdentifier": null,
            "endDateTime": "$expiryTime",
            "startDateTime": "$startTime",
            "displayName": "$Name"
        }        
    }
"@
    write-host "Setting Application Client Secret for $AppObjectId"
    $url = "https://graph.microsoft.com/beta/applications/$AppObjectId/addPassword"
    $appkey = Invoke-RestMethod -Uri $url -Headers $global:authHeader -Method POST -Body $passwordCredentials -ContentType "application/json"
    return $appkey
}
<#
.SYNOPSIS
    Registeres a test webapp

.DESCRIPTION
    Registeres a test webapp that can be used for testing B2C Custom Policies with. It redirects to jwt.ms

.PARAMETER DisplayName
    Name of app. 

.PARAMETER AppID
    AppID for your client_credentials. Default is to use $env:B2CAppID

.PARAMETER AppKey
    secret for your client_credentials. Default is to use $env:B2CAppKey

.EXAMPLE
    New-AzADB2CTestApp -n "ABC-WebApp"
#>
function New-AzADB2CTestApp
(
    [Parameter(Mandatory=$true)][Alias('n')][string]$DisplayName = "Test-WebApp"
)
{
    RefreshTokenIfExpired
    $tenantName = $global:tenantName
    # check that they don't already exists
    #$app = Invoke-GraphRestMethodGet "applications?`$filter=displayName eq '$DisplayName')"    
    $app = Get-Application -DisplayName $DisplayName
    if ( $app.value.Count -ge 1 ) {
        write-warning "App already exists $DisplayName"
        return
    }
    $requiredResourceAccess=@"
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
"@
    Add-AzADB2CApplication -DisplayName $DisplayName -redirectUris "https://jwt.ms" -requiredResourceAccess $requiredResourceAccess `
                    -WebApp -EnableIdTokenIssuance -EnableAccessTokenIssuance -Grant -SetOwner
}

<#
.SYNOPSIS
    Upload files to Azure Blob Storage

.DESCRIPTION
    Uploads files to Azure Blob Storage for use of custom html/css/javascript

.PARAMETER LocalFile
    Path to local file to upload

.PARAMETER StorageAccountName
    Name of Azure Storage Account

.PARAMETER ConatinerPath
    Name of Storage Container and the additional path. If can be "containername/path1/path2"

.PARAMETER StorageAccountKey
    Key to Storage Container

.PARAMETER EndpointSuffix
    Azure Storage Accounts endpoint suffic. Default is core.windows.net

.EXAMPLE
    Import-AzADB2CHtmlContent -f ".\html\unified.html" -a "yourstorageaccount" -p "containername/path1/path2" -k $stgkey

#>
function Import-AzADB2CHtmlContent (
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

<#
.SYNOPSIS
    Starts the Azure Portal

.DESCRIPTION
    Starts the Azure Portal in the right b2C tenant and with the B2C panel active

.PARAMETER tenantName
    tenant name to use. Default is current connection

.PARAMETER Chrome
    Use the Chrome browser. Default is your default browser

.PARAMETER Edge
    Use the Edge browser. Default is your default browser

.PARAMETER Firefox
    Use the Firefox browser. Default is your default browser

.PARAMETER Incognito
    Start the browser in incognito/inprivate mode (default). Specify -Incognito:$False to disable

.PARAMETER NewWindow
    Start the browser in a new window (default). Specify -NewWindow:$False to disable

.EXAMPLE
    Start-AzADB2CPortal

.EXAMPLE
    Start-AzADB2CPortal -t "yourtenant" -Firefox -NewWindow:$False
#>
function Start-AzADB2CPortal
(
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][switch]$Chrome = $False,
    [Parameter(Mandatory=$false)][switch]$Edge = $False,
    [Parameter(Mandatory=$false)][switch]$Firefox = $False,
    [Parameter(Mandatory=$false)][switch]$Incognito = $True,
    [Parameter(Mandatory=$false)][switch]$NewWindow = $True
)
{    
    if ( "" -eq $TenantName ) {
        $TenantName = $global:TenantName
    }
    if ( !($TenantName -imatch ".onmicrosoft.com") ) {
        $TenantName = $TenantName + ".onmicrosoft.com"
    }
    $url = "https://portal.azure.com/{0}#blade/Microsoft_AAD_B2CAdmin/TenantManagementMenuBlade/overview" -f $tenantName
    $pgm, $params = Get-BrowserInfo -Chrome $Chrome -Edge $Edge -Firefox $Firefox -Incognito $Incognito -NewWindow $NewWindow
    write-host "Starting Browser`n$url"
    Start-Browser -pgm $pgm -params $params -url $url        
}

<#
.SYNOPSIS
    Registers a Graph App

.DESCRIPTION
    Registers an application with needed Graph API Permissions for use with client credentials operations on B2C tenant

.PARAMETER DisplayName
    Name of app. Default is "B2C-Graph-App"

.PARAMETER CreateConfigFile
    If to generate the config file .\b2cAppSetings_yourtenant.json

.EXAMPLE
    New-AzADB2CGraphApp

.EXAMPLE
    New-AzADB2CGraphApp -n "B2C-GraphApp" -CreateConfigFile
#>
Function New-AzADB2CGraphApp
(
    [Parameter(Mandatory=$false)][Alias('n')][string]$DisplayName = "B2C-Graph-App",
    [Parameter(Mandatory=$false)][switch]$CreateConfigFile = $False
)
{
    $tenantName = $global:tenantName
    $tenantID = $global:tenantID
    write-host "$tenantName`n$($tenantId)"

    # 00000003 == MSGraph, 00000002 == AADGraph
    $requiredResourceAccess=@"
        {
            "resourceAppId": "00000003-0000-0000-c000-000000000000",
            "resourceAccess": [
{
					"id": "9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8",
					"type": "Role"
				},
				{
					"id": "4a771c9a-1cf2-4609-b88e-3d3e02d539cd",
					"type": "Role"
				},
				{
					"id": "fff194f1-7dce-4428-8301-1badb5518201",
					"type": "Role"
				},
				{
					"id": "79a677f7-b79d-40d0-a36a-3e6f8688dd7a",
					"type": "Role"
				},
				{
					"id": "246dd0d5-5bd0-4def-940b-0421030a5b68",
					"type": "Role"
				},
				{
					"id": "df021288-bdef-4463-88db-98f22de89214",
					"type": "Role"
				},
				{
					"id": "1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9",
					"type": "Role"
				},
				{
					"id": "5b567255-7703-4780-807c-7be8301ae99b",
					"type": "Role"
				},
				{
					"id": "62a82d76-70ea-41e2-9197-370581804d09",
					"type": "Role"
				},
				{
					"id": "19dbc75e-c2e2-444c-a770-ec69d8559fc7",
					"type": "Role"
				}
            ]
        },
        {
            "resourceAppId": "00000002-0000-0000-c000-000000000000",
            "resourceAccess": [
                {
                    "id": "311a71cc-e848-46a1-bdf8-97ff7156d8e6",
                    "type": "Scope"
                },
                {
                    "id": "5778995a-e1bf-45b8-affa-663a9f3f4d04",
                    "type": "Role"
                },
                {
                    "id": "78c8a3c8-a07e-4b9e-af1b-b5ccab50a175",
                    "type": "Role"
                }
                    ]
        }
"@

    $app = Add-AzADB2CApplication -DisplayName $DisplayName -redirectUris "https://$DisplayName" -requiredResourceAccess $requiredResourceAccess `
            -WebApp -signInAudience "AzureADMyOrg" -EnableIdTokenIssuance:$False -EnableAccessTokenIssuance:$False

    write-host "AppID`t`t$($app.AppId)`nObjectID:`t$($app.Id)"

    write-host "`nCreating App Key / Secret / client_secret - please remember this value and keep it safe"
    $AppSecret = Set-AzADB2CApplicationClientSecret -AppObjectId $app.id -Name "Key1"
    $AppSecretValue = $AppSecret.secretText

    $env:B2CAppId=$app.Id
    $env:B2CAppKey=$AppSecretValue
    $global:B2CAppId=$app.id
    $global:B2CAppKey=$AppSecretValue

    write-host "setting ENVVAR B2CAppID=$($App.appid)"
    $env:B2CAppId=$App.appid
    write-host "setting ENVVAR B2CAppKey=$($AppSecretValue)"
    $env:B2CAppKey=$AppSecretValue

    if ( $CreateConfigFile ) {
        $path = (get-location).Path
        $cfg = (Get-Content "$path\b2cAppSettings.json" | ConvertFrom-json)
        $global:ConfigPath = $cfg
        $cfg.ClientCredentials.client_id = $App.appid
        $cfg.ClientCredentials.client_secret = $AppSecretValue
        $cfg.TenantName = $tenantName
        $ConfigFile = "$path\b2cAppSettings_" + $tenantName.split(".")[0] + ".json"
        Set-Content -Path $ConfigFile -Value ($cfg | ConvertTo-json) 
        write-host "Saved to config file $ConfigFile"
    } else {
        write-host "Copy-n-paste this into your b2cAppSettings.json file `
        `"ClientCredentials`": { `
            `"client_id`": `"$($App.id)`", `
            `"client_secret`": `"$($AppSecretValue)`" `
        },"
    }
}

<#
.SYNOPSIS
    Registers a Local Admin user

.DESCRIPTION
    Registers a Local Admin user in the B2C tenant. This user is not a Signup user but a user given admin permissions in the tenant

.PARAMETER DisplayName
    DisplayName of user. Default is "GraphExplorer"

.PARAMETER username
    Name of user. Default is "graphexplorer". This will make the UPN "graphexplorer@yourtenant.onmicrosoft.com"

.PARAMETER Password
    Password for user. If not specified it will be prompted for

.PARAMETER RoleNames
    Collection of roles to grant the user, such as @("Directory Readers", "Directory Writers", "Global Administrator").
    If you specify an empty array @(), the user will be just a local account

.EXAMPLE
    New-AzADB2CLocalAdmin

.EXAMPLE
    New-AzADB2CLocalAdmin -DisplayName "Bob Contoso Admin" -username "bob" -RoleNames @("Global Administrator")

.EXAMPLE
    New-AzADB2CLocalAdmin -DisplayName "Bob Contoso" -username "bob" -RoleNames @()
#>
Function New-AzADB2CLocalAdmin
(
    [Parameter(Mandatory=$false)][Alias('d')][string]$displayName = "GraphExplorer",
    [Parameter(Mandatory=$false)][Alias('u')][string]$username = "graphexplorer",
    [Parameter(Mandatory=$false)][Alias('p')][string]$Password = "",
    [Parameter(Mandatory=$false)][Alias('r')][string[]]$RoleNames = @("Directory Readers", "Directory Writers") # @("Global Administrator")
)
{
    $tenantName = $global:tenantName
    $tenantID = $global:tenantId

    if ( "" -eq $Password ) {
        $cred = Get-Credential -UserName $DisplayName -Message "Enter userid for $TenantName"
        $Password = $cred.GetNetworkCredential().Password
    }
    if ( $username.Contains("@") ) {
        $email = $username
        $mailNickname = $username.Split("@")[0]
    } else {
        $email = "$username@$($global:tenantName)"
        $mailNickname = $username
    }
 $body = @"
        {
          "accountEnabled": true,
          "creationType": "LocalAccount",
          "userType": "Member",
          "displayName": "$displayName",
          "mailNickname": "$mailNickname",
          "passwordPolicies": "DisablePasswordExpiration,DisableStrongPassword",
          "passwordProfile": {
            "password": "$password",
            "forceChangePasswordNextSignIn": false
          },
          "identities": [
            {
              "signInType": "emailAddress",
              "issuer": "$global:tenantName",
              "issuerAssignedId": "$email"
            }
          ]
        }
"@
    RefreshTokenIfExpired
    $user = Invoke-GraphRestMethodPost "users" -Body $body
    write-host "User`t`t$username`nObjectID:`t$($user.id)"
    foreach( $roleName in $RoleNames) {
        $roles = Invoke-GraphRestMethodGet "directoryRoles?$filter=displayName eq '$roleName'&`$select=id,roleTemplateId" 
        $body = @"
{
  "@odata.id": "$GraphEndpoint/directoryObjects/$($user.id)"
}
"@
        $resp = Invoke-GraphRestMethodPost "directoryRoles/$($roles.value[0].id)/members/`$ref" -Body $body
        write-host "Adding role`t$roleName"
    }
}

<#
.SYNOPSIS
    Registers an extension attribute

.DESCRIPTION
    Registers an extension attribute in the B2C tenant

.PARAMETER AppDisplayName
    DisplayName of the app to use for the extension atribute. Default is "b2c-extension-app"

.PARAMETER AttributeName
    Name of Attribute. The full name will ne "extensions_{AppID}_{AttributeName}"

.PARAMETER DataType
    DataType for the attribute. Default is "string"

.EXAMPLE
    New-AzADB2CExtensionAttribute -AttributeName "requiresMigration" -DataType "Boolean"

#>
Function New-AzADB2CExtensionAttribute
(
    [Parameter(Mandatory=$False)][Alias('a')][string]$AppDisplayName = "b2c-extensions-app", # use this for default 
    [Parameter(Mandatory=$True)][Alias('n')][string]$attributeName = "", 
    [Parameter(Mandatory=$False)][Alias('d')][string]$dataType = "String" # String, Boolean, Date
)
{
    RefreshTokenIfExpired
    #$resp = Invoke-GraphRestMethodGet "applications?`$filter=startswith(displayName,'$AppDisplayName')&`$select=id,appid"
    $resp = Get-Application -DisplayNameStartsWith $AppDisplayName -Select "id,appid"
    if ( $resp.value.Length -ne 1 ) {
        write-warning "App does not exist $AppDisplayName"
        return
    }
    $appExt = $resp.value[0]    
$body = @"
{
    "name": "$attributeName",
    "dataType": "$dataType",
    "targetObjects": [ "User"]
}
"@
    $resp = Invoke-GraphRestMethodPost "applications/$($appExt.id)/extensionProperties" $body    
}
<#
.SYNOPSIS
    Removes an extension attribute

.DESCRIPTION
    Removes an extension attribute in the B2C tenant

.PARAMETER AppDisplayName
    DisplayName of the app to use for the extension atribute. Default is "b2c-extension-app"

.PARAMETER AttributeName
    Name of Attribute. The full name is "extensions_{AppID}_{AttributeName}"

.EXAMPLE
    Remove-AzADB2CExtensionAttribute -AttributeName "requiresMigration"

#>
Function Remove-AzADB2CExtensionAttribute
(
    [Parameter(Mandatory=$False)][Alias('a')][string]$AppDisplayName = "b2c-extensions-app", # use this for default 
    [Parameter(Mandatory=$True)][Alias('n')][string]$attributeName = ""
)
{
    RefreshTokenIfExpired
    #$resp = Invoke-GraphRestMethodGet "applications?`$filter=startswith(displayName,'$AppDisplayName')&`$select=id,appid"
    $resp = Get-Application -DisplayNameStartsWith $AppDisplayName -Select "id,appid"
    if ( $resp.value.Length -ne 1 ) {
        write-warning "App does not exist $AppDisplayName"
        return
    }
    $appExt = $resp.value[0]    
    $fullAttrName = "extension_" + $appExt.appid.Replace("-","") + "_$attributeName"
    #$resp = Invoke-GraphRestMethodGet "applications/$($appExt.id)/extensionProperties?`$filter=name eq '$fullAttrName'&`$select=id,appid"
    $resp = Get-Application -Path "$($appExt.id)/extensionProperties" -Select "id,appid"
    if ( $resp.value.Length -ne 1 ) {
        write-warning "Extension Attribute does not exist $fullAttrName"
        return
    }
    $resp = Invoke-GraphRestMethodDelete "applications/$($appExt.id)/extensionProperties/$($resp.value[0].id)"
}

<#
.SYNOPSIS
    Get extension attributes for user

.DESCRIPTION
    Get extension attributes for user

.PARAMETER signInName
    The signInName of the user. Can be email, username or phone number. 

.PARAMETER AttributeName
    objectId of user. Either signInName or objectId must be defined

.EXAMPLE
    Get-AzADB2CExtensionAttributesForUser -signInName "alice@contoso.com"

.EXAMPLE
    Get-AzADB2CExtensionAttributesForUser -objectId "280f8d4e-26a4-4d4e-9327-4b76d52ab8e9"

#>
Function Get-AzADB2CExtensionAttributesForUser
(
    [Parameter(Mandatory=$false)][Alias('u')][string]$signInName = "",
    [Parameter(Mandatory=$false)][Alias('o')][string]$objectId = ""
)
{
    RefreshTokenIfExpired
    if ( "" -ne $signInName ) {
        $users = Invoke-GraphRestMethodGet "users?`$filter=identities/any(c:c/issuerAssignedId eq '$signInName' and c/issuer eq '$($global:TenantName)')"
        if ( $users.value.Count -eq 0 ) {
            write-error "User with signInName $signInName not found"
            return
        }
        $user = $users.value[0]
    } else {
        $user = Invoke-GraphRestMethodGet "users/$objectId"
    }
    foreach( $extattr in $user.psobject.properties.Where({$_.Name.StartsWith("extension_")}) ) {
        write-host $extattr.TypeNameOfValue.Replace("System.", "") "`t" $extattr.Name "`t" $extattr.Value
    }
}

<#
.SYNOPSIS
    Updates an extension attributes for user

.DESCRIPTION
    Updates an extension attributes for user

.PARAMETER signInName
    The signInName of the user. Can be email, username or phone number. 

.PARAMETER AppDisplayName
    DisplayName of the app to use for the extension atribute. Default is "b2c-extension-app"

.PARAMETER AttributeName
    objectId of user. Either signInName or objectId must be defined

.PARAMETER AttributeValue
    Value to set

.EXAMPLE
    Set-AzADB2CExtensionAttributeForUser -signInName "alice@contoso.com" -AttributeName "requiresMigration" -AttributeValue "true"

.EXAMPLE
    Set-AzADB2CExtensionAttributesForUser -objectId "280f8d4e-26a4-4d4e-9327-4b76d52ab8e9" -AttributeName "requiresMigration" -AttributeValue "true"

#>
Function Set-AzADB2CExtensionAttributeForUser
(
    [Parameter(Mandatory=$false)][Alias('u')][string]$signInName = "",
    [Parameter(Mandatory=$false)][Alias('o')][string]$objectId = "",
    [Parameter(Mandatory=$False)][Alias('n')][string]$AppDisplayName = "b2c-extensions-app", # use this for default 
    [Parameter(Mandatory=$True)][Alias('a')][string]$attributeName = "",
    [Parameter(Mandatory=$True)][Alias('v')][string]$attributeValue = ""
)
{
    if ( "" -ne $signInName ) {
        $users = Invoke-GraphRestMethodGet "users?`$filter=identities/any(c:c/issuerAssignedId eq '$signInName' and c/issuer eq '$($global:TenantName)')"
        if ( $users.value.Count -eq 0 ) {
            write-error "User with signInName $signInName not found"
            return
        }
        $user = $users.value[0]
    } else {
        $user = Invoke-GraphRestMethodGet "users/$objectId"
    }
    $resp = Invoke-GraphRestMethodGet "applications?`$filter=startswith(displayName,'$AppDisplayName')&`$select=id,appid"
    if ( $resp.value.Length -ne 1 ) {
        write-warning "App does not exist $AppDisplayName"
        return
    }
    $appExt = $resp.value[0]    
    $fullAttrName = "extension_" + $appExt.appid.Replace("-","") + "_$attributeName"
    #$resp = Invoke-GraphRestMethodGet "applications/$($appExt.id)/extensionProperties?`$filter=name eq '$fullAttrName'&`$select=id,appid"
    $resp = Get-Application -Path "$($appExt.id)/extensionProperties" -Select "id,appid"
    if ( $resp.value.Length -ne 1 ) {
        write-warning "Extension Attribute does not exist $fullAttrName"
        return
    }
$body = @"
{
    "$fullAttrName": "$attributeValue"
}
"@
    $resp = Invoke-GraphRestMethodPatch "users/$($user.id)" $body    
}

<#
.SYNOPSIS
    Lists all available custom domain names for the current tenant

.DESCRIPTION
    Lists all available custom domain names for the current tenant

.PARAMETER SetGlobalVariable
    Sets the global variable $global:B2CCustomDomain which is used by the Test-AzADB2CPolicy cmdlet

.EXAMPLE
    Get-AzADB2CCustomDomain

.EXAMPLE
    Get-AzADB2CCustomDomain -SetGlobalVariable

#>
Function Get-AzADB2CCustomDomain
(
    [Parameter(Mandatory=$false)][switch]$SetGlobalVariable = $False 
)
{
    RefreshTokenIfExpired
    $resp = Invoke-GraphRestMethodGet "domains"
    $B2CCustomDomains = @()
    foreach( $domain in $resp.value.id) { 
        if ( !$domain.EndsWith(".onmicrosoft.com") ) {
            $B2CCustomDomains += $domain
            $nsresp = ((nslookup -type=CNAME $domain) -join " ") 2>$null
            if ( $nsresp.Contains(".azurefd.net") ) {
                if ( $SetGlobalVariable ) {
                    $global:B2CCustomDomain = $domain
                }          
            }
        }
    }
    return $B2CCustomDomains
}   

<#
.SYNOPSIS
    Adds a ClaimsProvider

.DESCRIPTION
    Adds a ClaimsProvider configuration to the TrustFrameworkExtensions.xml file

.PARAMETER PolicyPath
    Path to policy files. Default is current directory

.PARAMETER RelyingPartyFileName
    Name of relying party file. Default is SignUpOrSignin.xml

.PARAMETER BasePolicyFileName
    Name of base configuration file. Default is TrustFrameworkBase.xml

.PARAMETER ExtPolicyFileName
    Name of extension configuration file. Default is TrustFrameworkExtensions.xml

.EXAMPLE
    Add-AzADB2CSAML2Protocol 

.EXAMPLE
    Add-AzADB2CSAML2Protocol -RelyingPartyFileName "PasswordReset.xml"
#>
function Add-AzADB2CSAML2Protocol (
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",    
    [Parameter(Mandatory=$false)][Alias('r')][string]$RelyingPartyFileName = "SignUpOrSignin.xml",
    [Parameter(Mandatory=$false)][Alias('b')][string]$BasePolicyFileName = "TrustFrameworkBase.xml",
    [Parameter(Mandatory=$false)][Alias('e')][string]$ExtPolicyFileName = "TrustFrameworkExtensions.xml"
)
{
    RefreshTokenIfExpired
    if ( "" -eq $PolicyPath ) {
        $PolicyPath = (get-location).Path
    }        
    [xml]$rp =Get-Content -Path "$PolicyPath/$RelyingPartyFileName" -Raw
    [xml]$ext =Get-Content -Path "$PolicyPath/$ExtPolicyFileName" -Raw
    if ((Test-Path -Path "$PolicyPath/$BasePolicyFileName" -PathType Leaf) -eq $True ) {
        [xml]$base = Get-Content -Path "$PolicyPath/$BasePolicyFileName" -Raw
    } else {
        [xml]$base = Get-AzADB2CPolicyId -PolicyId $ext.TrustFrameworkPolicy.BasePolicy.PolicyId
    }
    $samleTpId="Saml2AssertionIssuer"

$samlClaimsProviderXml=@"
<ClaimsProvider>
  <DisplayName>Token Issuer</DisplayName>
  <TechnicalProfiles>
    <!-- SAML Token Issuer technical profile -->
    <TechnicalProfile Id="$($samleTpId)">
      <DisplayName>Token Issuer</DisplayName>
      <Protocol Name="None"/>
      <OutputTokenFormat>SAML2</OutputTokenFormat>
      <Metadata>
        <!-- The issuer contains the policy name; it should be the same name as configured in the relying party application. B2C_1A_signup_signin_SAML is used below. -->
        <Item Key="IssuerUri">https://$($global:TenantName.Split(".")[0]).b2clogin.com/$($global:TenantName).onmicrosoft.com/$($rp.TrustFrameworkPolicy.PolicyId)</Item>
      </Metadata>
      <CryptographicKeys>
        <Key Id="MetadataSigning" StorageReferenceId="B2C_1A_SamlIdpCert"/>
        <Key Id="SamlAssertionSigning" StorageReferenceId="B2C_1A_SamlIdpCert"/>
        <Key Id="SamlMessageSigning" StorageReferenceId="B2C_1A_SamlIdpCert"/>
      </CryptographicKeys>
      <InputClaims/>
      <OutputClaims/>
      <UseTechnicalProfileForSessionManagement ReferenceId="SM-Saml-sp"/>
    </TechnicalProfile>
    <!-- Session management technical profile for SAML based tokens -->
    <TechnicalProfile Id="SM-Saml-sp">
      <DisplayName>Session Management Provider</DisplayName>
      <Protocol Name="Proprietary" Handler="Web.TPEngine.SSO.SamlSSOSessionProvider, Web.TPEngine, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null"/>
    </TechnicalProfile>

  </TechnicalProfiles>
</ClaimsProvider>
"@

$rpXml=@"
  <UserJourneys>
    <UserJourney Id="SignUpOrSignIn">
      <AssuranceLevel>LOA1</AssuranceLevel>
      <OrchestrationSteps>
        <!-- override Base step 7 and emit a SAML token instead of JWT -->
        <OrchestrationStep Order="7" Type="SendClaims" CpimIssuerTechnicalProfileReferenceId="$($samleTpId)" />
      </OrchestrationSteps>
    </UserJourney>
  </UserJourneys>
"@

    if ( $ext.TrustFrameworkPolicy.ClaimsProviders.InnerXml -imatch "SAML2" ) {
    write-warning "SAML2 Token Issuer seems to already exists"
    return
    }

    write-host "Adding TechnicalProfileId $samleTpId"

    $ext.TrustFrameworkPolicy.ClaimsProviders.innerXml = $ext.TrustFrameworkPolicy.ClaimsProviders.innerXml + $samlClaimsProviderXml

    $rp.TrustFrameworkPolicy.RelyingParty.TechnicalProfile.Protocol.Name = "SAML2"
    $rp.TrustFrameworkPolicy.innerXml = $rp.TrustFrameworkPolicy.innerXml.Replace("</BasePolicy>", "</BasePolicy>" + $rpXml )
    $attr = $rp.CreateAttribute("ExcludeAsClaim")
    $rp.TrustFrameworkPolicy.RelyingParty.TechnicalProfile.SubjectNamingInfo.Attributes.Append($attr) | Out-null
    $rp.TrustFrameworkPolicy.RelyingParty.TechnicalProfile.SubjectNamingInfo.ExcludeAsClaim="false"
    $rp.TrustFrameworkPolicy.RelyingParty.TechnicalProfile.SubjectNamingInfo.ClaimType="objectId"
    foreach( $outputClaim in $rp.TrustFrameworkPolicy.RelyingParty.TechnicalProfile.OutputClaims.OutputClaim ) {
        if ( $outputClaim.ClaimTypeReferenceId -eq "email" ) {
            $outputClaim.ClaimTypeReferenceId = "signInName"
            $attr = $rp.CreateAttribute("PartnerClaimType")
            $outputClaim.Attributes.Append($attr) | Out-null
            $outputClaim.PartnerClaimType="http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
        }
        if ( $outputClaim.ClaimTypeReferenceId -eq "objectId" ) {
            $outputClaim.PartnerClaimType="http://schemas.microsoft.com/identity/claims/objectidentifier"
        }
    }
    $ext.Save("$PolicyPath/$ExtPolicyFileName")
    $rp.Save("$PolicyPath/$RelyingPartyFileName")
}

<#
.SYNOPSIS
    Gets id, access and refresh tokens from a B2C tenant using Device Login flow

.DESCRIPTION
    If you need an access token to make Graph API calls to your B2C tenant, you can use this command to retrieve it

.PARAMETER ClientID
    Default is well-known client_id for Powershell.

.PARAMETER TenantID
    Specify the tenant name (yourtenant.onmicrosoft.com) or the id (guid) for the tenant

.PARAMETER Resource
    The default resource is https://graph.microsoft.com

.PARAMETER Scope
    Additional scopes you want for the access token

.PARAMETER Chrome
    Use the Chrome browser. Default is your default browser

.PARAMETER Edge
    Use the Edge browser. Default is your default browser

.PARAMETER Firefox
    Use the Firefox browser. Default is your default browser

.PARAMETER Incognito
    Start the browser in incognito/inprivate mode (default). Specify -Incognito:$False to disable

.PARAMETER NewWindow
    Start the browser in a new window (default). Specify -NewWindow:$False to disable

.PARAMETER Incognito
    If to launch the browser in an incognito/inprivate window

.EXAMPLE
    $tokens = Connect-AzADB2CDevicelogin -TenantName "yourtenant.onmicrosoft.com" -Scope "User.Read.All" 

.EXAMPLE
    $tokens = Connect-AzADB2CDevicelogin -TenantName "yourtenant.onmicrosoft.com" -Scope "Directory.ReadWrite.All" 
#>
function Connect-AzADB2CDevicelogin {
    [cmdletbinding()]
    param( 
        [Parameter()][Alias('c')]$ClientID = '1950a258-227b-4e31-a9cf-717495945fc2',        
        [Parameter()][Alias('t')]$TenantName = 'common',        
        [Parameter()][Alias('r')]$Resource = "https://graph.microsoft.com/",        
        [Parameter()][Alias('s')]$Scope = "",        
        # Timeout in seconds to wait for user to complete sign in process
        [Parameter(DontShow)]$Timeout = 300,
        [Parameter(Mandatory=$false)][switch]$Chrome = $False,
        [Parameter(Mandatory=$false)][switch]$Edge = $False,
        [Parameter(Mandatory=$false)][switch]$Firefox = $False,
        [Parameter(Mandatory=$false)][switch]$Incognito = $True,
        [Parameter(Mandatory=$false)][switch]$NewWindow = $True
    )

    Function IIf($If, $Right, $Wrong) {If ($If) {$Right} Else {$Wrong}}
    
    if ( $TenantName -ne "common" -and ($TenantName -imatch ".onmicrosoft.com") -eq $false ) {
        $TenantName = $TenantName + ".onmicrosoft.com"
    }

    if ( !($Scope -imatch "offline_access") ) { $Scope += " offline_access"} # make sure we get a refresh token
    $retVal = $null
    $url = "https://microsoft.com/devicelogin"
    $pgm, $params = Get-BrowserInfo -Chrome $Chrome -Edge $Edge -Firefox $Firefox -Incognito $Incognito -NewWindow $NewWindow
    try {
        $DeviceCodeRequestParams = @{
            Method = 'POST'
            Uri    = "https://login.microsoftonline.com/$TenantName/oauth2/devicecode"
            Body   = @{
                resource  = $Resource
                client_id = $ClientId
                scope = $Scope
            }
        }
        $DeviceCodeRequest = Invoke-RestMethod @DeviceCodeRequestParams
        #write-host $DeviceCodeRequest
        Write-Host $DeviceCodeRequest.message -ForegroundColor Yellow
        $url = $DeviceCodeRequest.verification_url

        Set-Clipboard -Value $DeviceCodeRequest.user_code

        Start-Browser -pgm $pgm -params $params -url $url        

        $TokenRequestParams = @{
            Method = 'POST'
            Uri    = "https://login.microsoftonline.com/$TenantName/oauth2/token"
            Body   = @{
                grant_type = "urn:ietf:params:oauth:grant-type:device_code"
                code       = $DeviceCodeRequest.device_code
                client_id  = $ClientId
            }
        }
        $TimeoutTimer = [System.Diagnostics.Stopwatch]::StartNew()
        while ([string]::IsNullOrEmpty($TokenRequest.access_token)) {
            if ($TimeoutTimer.Elapsed.TotalSeconds -gt $Timeout) {
                throw 'Login timed out, please try again.'
            }
            $TokenRequest = try {
                Invoke-RestMethod @TokenRequestParams -ErrorAction Stop
            }
            catch {
                $Message = $_.ErrorDetails.Message | ConvertFrom-Json
                if ($Message.error -ne "authorization_pending") {
                    throw
                }
            }
            Start-Sleep -Seconds 1
        }
        $retVal = $TokenRequest
        #write-host $TokenRequest.access_token
    }
    finally {
        try {
            $TimeoutTimer.Stop()
        }
        catch {
            # We don't care about errors here
        }
    }
    $global:ClientID = $ClientID 
    $global:TenantName = $TenantName 
    $global:TenantID = Get-TenantIdFromName -TenantName $TenantName
    $global:tokens = $retval
    $global:authHeader =@{ 'Authorization'=$retval.token_type + ' ' + $retval.access_token }
    $global:token_expires_on = $retval.expires_on
    $global:authMethod = "Connect-AzADB2CDevicelogin"

    $part1=$retval.access_token.Split(".")[1]
    $fill = ""
    if ( ($part1.Length % 4) -ne 0 ) {
        $fill = "="*(4 - ($part1.Length % 4))
    }
    $jsonAccessToken = ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String( "$part1$fill" )) | ConvertFrom-json)
    $global:userObjectId = $jsonAccessToken.oid
    $user = $jsonAccessToken.email
    $TenantShort = $TenantName.Replace(".onmicrosoft.com", "")

    $host.ui.RawUI.WindowTitle = "B2C $TenantShort - $user"

    #return $retVal
}
<#
.SYNOPSIS
    Adds KMSI (Keep me signed in) to the signin page

.DESCRIPTION
    Adds KMSI (Keep me signed in) to the signin page

.PARAMETER PolicyPath
    Path to policy files. Default is current directory

.PARAMETER TechnicalProfileId
    Id of the Technical Profile to add KMSI too. The default is "SelfAsserted-LocalAccountSignin-Email"

.PARAMETER ExtPolicyFileName
    Name of extension configuration file. Default is TrustFrameworkExtensions.xml

.EXAMPLE
    Set-AzADB2CKmsi

.EXAMPLE
    Set-AzADB2CKmsi -TechnicalProfileId "SelfAsserted-LocalAccountSignin-Email"
#>
function Set-AzADB2CKmsi (
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",    
    [Parameter(Mandatory=$false)][Alias('i')][string]$TechnicalProfileId = "SelfAsserted-LocalAccountSignin-Email",
    [Parameter(Mandatory=$false)][Alias('e')][string]$ExtPolicyFileName = "TrustFrameworkExtensions.xml"
)
{
    if ( "" -eq $PolicyPath ) {
        $PolicyPath = (get-location).Path
    }

    [xml]$ext =Get-Content -Path "$PolicyPath\$ExtPolicyFileName" -Raw

$newxml = @"
<ClaimsProvider>
  <DisplayName>Local Account</DisplayName>
  <TechnicalProfiles>
    <TechnicalProfile Id="$TechnicalProfileId">
      <Metadata>
        <Item Key="setting.enableRememberMe">True</Item>
        <!-- <Item Key="setting.operatingMode">username</Item>--> <!-- this enables signin with username -->
      </Metadata>
    </TechnicalProfile>
  </TechnicalProfiles>
</ClaimsProvider>
"@

    $cpExists = $false
    foreach( $cp in $ext.TrustFrameworkPolicy.ClaimsProviders.ClaimsProvider ) {
        if ( "Local Account" -eq $cp.DisplayName ) {
            $cpExists = $true
            $cp.InnerXML = $cp.InnerXML.Replace( "</ClaimsProviders>", $newxml + "</ClaimsProviders>")
        }
    }

    if ( !$cpExists ) {
        $ext.TrustFrameworkPolicy.InnerXML = $ext.TrustFrameworkPolicy.InnerXML.Replace( "</ClaimsProviders>", $newxml + "</ClaimsProviders>")
    }
    $ext.Save("$PolicyPath/$ExtPolicyFileName")
}

<#
.SYNOPSIS
    Add Localization to Signup/Signin page

.DESCRIPTION
    Add Localization to Signup/Signin page

.PARAMETER PolicyPath
    Path to policy files. Default is current directory

.PARAMETER ContentDefinitionId
    Id of the ContentDefinition. The default is "api.signuporsignin"

.PARAMETER Language
    Language code. Default is "en"

.PARAMETER ExtPolicyFileName
    Name of extension configuration file. Default is TrustFrameworkExtensions.xml

.EXAMPLE
    Set-AzADB2CLocalization

.EXAMPLE
    Set-AzADB2CLocalization -ContentDefinitionId = "api.signuporsignin" -Language "en"
#>
function Set-AzADB2CLocalization (
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",    
    [Parameter(Mandatory=$false)][Alias('i')][string]$ContentDefinitionId = "api.signuporsignin",
    [Parameter(Mandatory=$false)][Alias('l')][string]$Language = "en",
    [Parameter(Mandatory=$false)][Alias('e')][string]$ExtPolicyFileName = "TrustFrameworkExtensions.xml"
)
{
    if ( "" -eq $PolicyPath ) {
        $PolicyPath = (get-location).Path
    }
    [xml]$ext =Get-Content -Path "$PolicyPath\$ExtPolicyFileName" -Raw

$newxml = @"
<LocalizedResourcesReferences MergeBehavior="Prepend"><LocalizedResourcesReference Language="en" LocalizedResourcesReferenceId="api.signuporsignin.en" /></LocalizedResourcesReferences>
"@

$LocalizedResourcesReferenceId = "$ContentDefinitionId.$Language"

foreach( $cdef in $ext.TrustFrameworkPolicy.BuildingBlocks.ContentDefinitions.ContentDefinition ) {
    if ( $ContentDefinitionId -eq $cdef.Id ) {
$newxml = @"
<LocalizedResourcesReferences MergeBehavior="Prepend">
<LocalizedResourcesReference Language="$lang" LocalizedResourcesReferenceId="$LocalizedResourcesReferenceId" />
</LocalizedResourcesReferences>
"@
        $cdef.InnerXML = $cdef.InnerXML.Replace("</DataUri>", "</DataUri>" + $newxml)
    }
}

$xmlLoc = @"
    <Localization Enabled="true">
      <SupportedLanguages DefaultLanguage="$lang" MergeBehavior="ReplaceAll">
        <SupportedLanguage>$lang</SupportedLanguage>
      </SupportedLanguages>
      <LocalizedResources Id="$LocalizedResourcesReferenceId">
        <LocalizedStrings>
          <LocalizedString ElementType="UxElement" StringId="forgotpassword_link">Need help signing in?</LocalizedString>
          <LocalizedString ElementType="UxElement" StringId="remember_me">Remember me</LocalizedString>
          <LocalizedString ElementType="UxElement" StringId="social_intro">Other ways to signin</LocalizedString>
          <LocalizedString ElementType="UxElement" StringId="local_intro_generic">Sign in</LocalizedString>
          <LocalizedString ElementType="UxElement" StringId="createaccount_intro">Don't have an account?</LocalizedString>
          <LocalizedString ElementType="UxElement" StringId="createaccount_one_link">Sign up</LocalizedString>
        </LocalizedStrings>
      </LocalizedResources>
    </Localization>    
"@
    $ext.TrustFrameworkPolicy.InnerXml = $ext.TrustFrameworkPolicy.InnerXml.Replace( "</BuildingBlocks>", $xmlLoc + "</BuildingBlocks>" )
    $ext.Save("$PolicyPath/$ExtPolicyFileName")
}

<#
.SYNOPSIS
    Renumbers UserJourney Order numbers

.DESCRIPTION
    Makes sure UserJourney Numbers are in sequence 1..n with no gaps ord duplicates

.PARAMETER PolicyPath
    Path to policy files. Default is current directory

.PARAMETER PolicyFile
    Path to policy file. Default is TrustFrameworkExtensions.xml

.EXAMPLE
    Repair-AzADB2CUserJourneyOrder 

.EXAMPLE
    Repair-AzADB2CUserJourneyOrder -PolicyFile .\SignupOrSignin.xml
#>
function Repair-AzADB2CUserJourneyOrder (
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",    
    [Parameter(Mandatory=$false)][Alias('f')][string]$PolicyFile = "TrustFrameworkExtensions.xml"
)
{
    if ( "" -eq $PolicyPath ) {
        $PolicyPath = (get-location).Path
    }
    "$PolicyPath/$PolicyFile"    
    [xml]$ext =Get-Content -Path "$PolicyPath/$PolicyFile" -Raw

    foreach( $uj in $ext.TrustFrameworkPolicy.UserJourneys.UserJourney) { 
        $uj.Id
        $order = 1
        foreach( $steps in $uj.OrchestrationSteps ) {
            foreach( $step in $steps.OrchestrationStep ) {
                $step.Order = "$order"
                $order++
            }        
        }
    }
    $ext.Save("$PolicyPath/$PolicyFile")
}

<#
.SYNOPSIS
    Get the Tenant Region

.DESCRIPTION
    Get the Tenant Region

.EXAMPLE
    Get-AzADB2CTenantRegion

#>
function Get-AzADB2CTenantRegion
(
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = ""
    )
{

if ( "" -eq $TenantName ) { $TenantName = $global:TenantName }

$resp = Invoke-RestMethod -Uri "https://login.microsoft.com/$TenantName/v2.0/.well-known/openid-configuration"
$tenantRegion = $resp.tenant_region_scope
return $tenantRegion
}

<#
.SYNOPSIS
    Get the B2C Policy file inheritance tree

.DESCRIPTION
    Get the B2C Policy file inheritance tree and returns it as an object or draws it like a tree

.EXAMPLE
    $ret = Get-AzADB2CPolicyTree 

.EXAMPLE
    Get-AzADB2CPolicyTree -DrawTree

#>
function Get-AzADB2CPolicyTree
(
    [Parameter(Mandatory=$false)][switch]$DrawTree = $False
    )
{
    RefreshTokenIfExpired
    write-host "Getting a list of policies..."
    $resp = Invoke-GraphRestMethodGet "trustFramework/policies" -ContentType "application/xml"
    $policies = $resp.value

    $arr = @()

    write-host "Getting policy details..."
    foreach( $id in $policies.Id) {
        $resp = Invoke-GraphRestMethodGet "trustFramework/policies/$Id/`$value" -ContentType "application/xml"
        [xml]$policy = $resp.OuterXml
        $policyObj = New-Object System.Object
        $policyObj | Add-Member -type NoteProperty -name "PolicyId" -Value $policy.TrustFrameworkPolicy.PolicyId
        $policyObj | Add-Member -type NoteProperty -name "BasePolicyId" -Value $policy.TrustFrameworkPolicy.BasePolicy.PolicyId
        $policyObj | Add-Member -type NoteProperty -name "ReferencedBy" -Value @()
        $arr += $policyObj
    }

    function SetReferencedByPolicy( $policyObj ) {
        $refs = ($arr | where {$_.BasePolicyId -eq $policyObj.PolicyId}).PolicyId
        if ( $null -ne $refs ) {
            $policyObj.ReferencedBy += $refs
            foreach( $refId in $policyObj.ReferencedBy ) {
                $refObj = ($arr | where {$_.PolicyId -eq $refId})
                SetReferencedByPolicy $refObj
            }
        }
    }

    # walk through the policies with no base
    foreach( $basePolicy in ($arr | where {$_.BasePolicyId -eq $Null }) ) {
        SetReferencedByPolicy $basePolicy
    }

    if ( $DrawTree ) {
        function DrawInheritance( $policyId, $indent ) {
            $obj = ($arr | where {$_.PolicyId -eq $PolicyId})
            write-host "$indent $($obj.PolicyId)" 
            foreach( $refId in $obj.ReferencedBy ) {
                DrawInheritance $refId "$indent  "
            }
        }
        foreach( $basePolicy in ($arr | where {$_.BasePolicyId -eq $Null }) ) {
            DrawInheritance $basePolicy.PolicyId ""
            write-host ""
        }

    } else {
        return $arr
    }
}

<#
.SYNOPSIS
    Get the Tenant name from id

.DESCRIPTION
    converts tenant ids (guids) to real names, like yourtenant.onmicrosoft.com

.EXAMPLE
    Get-AzADB2CTenantId -TenantId "b6c11183-fc66-4937-86fe-98a7af31a023"

#>
function Get-AzADB2CTenantId
(
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantId = ""
)
{
    $resp = Invoke-RestMethod -Method "GET" -Uri "https://login.microsoft.com/$tenantId/metadata/json/1"
    foreach( $allowedAudiences in $resp.allowedAudiences ) {
        write-host $allowedAudiences.Split("@")[1]
    }
}

Export-ModuleMember -function Add-AzADB2CSAML2Protocol
Export-ModuleMember -function Connect-AzADB2CDevicelogin
Export-ModuleMember -function Connect-AzADB2C
Export-ModuleMember -function Remove-AzADB2CPolicyFromTenant
Export-ModuleMember -function Import-AzADB2CHtmlContent
Export-ModuleMember -function Import-AzADB2CPolicyToTenant
Export-ModuleMember -function Enable-AzADB2CIdentityExperienceFramework
Export-ModuleMember -function Get-AzADB2CCustomDomain
Export-ModuleMember -function Get-AzADB2CExtensionAttributesForUser
Export-ModuleMember -function Get-AzADB2CPolicyId
Export-ModuleMember -function Get-AzADB2CPolicyTree
Export-ModuleMember -function Get-AzADB2CStarterPack
Export-ModuleMember -function Get-AzADB2CTenantId
Export-ModuleMember -function Get-AzADB2CTenantRegion
Export-ModuleMember -function Get-AzADB2CPolicyIds
Export-ModuleMember -function New-AzADB2CExtensionAttribute
Export-ModuleMember -function New-AzADB2CGraphApp
Export-ModuleMember -function New-AzADB2CIdentityExperienceFrameworkApps
Export-ModuleMember -function New-AzADB2CLocalAdmin
Export-ModuleMember -function New-AzADB2CPolicyKey
Export-ModuleMember -function New-AzADB2CPolicyProject
Export-ModuleMember -function New-AzADB2CTestApp
Export-ModuleMember -function Read-AzADB2CConfig
Export-ModuleMember -function Remove-AzADB2CExtensionAttribute
Export-ModuleMember -function Repair-AzADB2CUserJourneyOrder
Export-ModuleMember -function Set-AzADB2CAppInsights
Export-ModuleMember -function Add-AzADB2CClaimsProvider
Export-ModuleMember -function Set-AzADB2CCustomAttributeApp
Export-ModuleMember -function Set-AzADB2CCustomizeUX
Export-ModuleMember -function Set-AzADB2CExtensionAttributeForUser
Export-ModuleMember -function Set-AzADB2CKmsi
Export-ModuleMember -function Set-AzADB2CLocalization
Export-ModuleMember -function Set-AzADB2CPolicyDetails
Export-ModuleMember -function Start-AzADB2CPortal
Export-ModuleMember -function Test-AzADB2CPolicy