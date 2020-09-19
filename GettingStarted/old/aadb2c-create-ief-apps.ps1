param (
    [Parameter(Mandatory=$false)][Alias('n')][string]$DisplayName = "IdentityExperienceFramework",
    [Parameter(Mandatory=$false)][boolean]$AzureCli = $False         # if to force Azure CLI on Windows
    )

$isWinOS = ($env:PATH -imatch "/usr/bin" )                 # Mac/Linux

if ( $False -eq $isWinOS -or $True -eq $AzureCli ) {
    write-host "Getting Tenant info..."
    $tenant = Get-AzureADTenantDetail
    $tenantName = $tenant.VerifiedDomains[0].Name
    $tenantID = $tenant.ObjectId
} else {
    $tenantName = $global:tenantName
    $tenantID = $global:tenantID
}
write-host "$tenantName`n$tenantId"

Function CreateRequiredResourceAccess([string]$ResourceAppId,[string]$ResourceAccessId, [string]$Type) {
    #write-host "Adding RequiredResourceAccess $ResourceAppId of type $Type..."
    $req = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
    $req.ResourceAppId = $ResourceAppId
    $req.ResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList $ResourceAccessId,$Type
    return $req
}

Function CreateApplication( [string]$DisplayName, [string]$TenantName, [bool]$NativeApp, [System.Array]$RequiredResourceAccess) {    
    if ( $false -eq $NativeApp ) {
        write-host "`nCreating WebApp $DisplayName..."
        $app = New-AzureADApplication -DisplayName $DisplayName -IdentifierUris "http://$TenantName/$DisplayName" -ReplyUrls @("https://$DisplayName") # WebApp
    } else {
        write-host "`nCreating NativeApp $DisplayName..."
        $app = New-AzureADApplication -DisplayName $DisplayName -IdentifierUris "http://$TenantName/$DisplayName" -ReplyUrls @("https://$DisplayName") -PublicClient $true # NativeApp
    }
    write-output "AppID`t`t$($app.AppId)`nObjectID:`t$($App.ObjectID)"

    # update the required permissions
    if ( $null -ne $RequiredResourceAccess ) {
        Set-AzureADApplication -ObjectId $app.ObjectId -RequiredResourceAccess $RequiredResourceAccess
    }

    write-host "Creating ServicePrincipal..."
    $sp = New-AzureADServicePrincipal -AccountEnabled $true -AppId $App.AppId -AppRoleAssignmentRequired $false -DisplayName $DisplayName 
    write-host "AppID`t`t$($sp.AppId)`nObjectID:`t$($sp.ObjectID)"
    <#
    $App = Get-AzureADApplication -SearchString $displayName
    $sp = Get-AzureADServicePrincipal -SearchString $displayName
    #>
    return $app
}

$AzureAdGraphApiAppID = "00000002-0000-0000-c000-000000000000"  # https://graph.windows.net
$scopeUserReadId = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"       # User.Read
$scopeUserRead = "User.Read"

$ProxyDisplayName = "Proxy$DisplayName"

if ( $False -eq $isWinOS -or $True -eq $AzureCli ) {
    $req1 = CreateRequiredResourceAccess -ResourceAppId $AzureAdGraphApiAppID -ResourceAccessId $scopeUserReadId -Type "Scope"
    $appIEF = CreateApplication -DisplayName $DisplayName -TenantName $tenantName -RequiredResourceAccess @($req1) -NativeApp $false

    $req2 = CreateRequiredResourceAccess -ResourceAppId $appIEF.AppId -ResourceAccessId $appIEF.Oauth2Permissions.Id -Type "Scope"
    $appPIEF = CreateApplication -DisplayName $ProxyDisplayName -TenantName $tenantName -RequiredResourceAccess @($req1,$req2) -NativeApp $true

    & $PSScriptRoot\aadb2c-app-grant-permission.ps1 -n $DisplayName
    & $PSScriptRoot\aadb2c-app-grant-permission.ps1 -n $ProxyDisplayName
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


