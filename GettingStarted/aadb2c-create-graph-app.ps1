param (
    [Parameter(Mandatory=$false)][Alias('n')][string]$DisplayName = "B2C-Graph-App",
    [Parameter(Mandatory=$false)][boolean]$AzureCli = $False,         # if to force Azure CLI on Windows
    [Parameter(Mandatory=$false)][switch]$CreateConfigFile = $False
    )

$isWinOS = ($env:PATH -imatch "/usr/bin" )                 # Mac/Linux
if ( $isWinOS ) { $AzureCLI = $True}

$tenantName = $global:tenantName
$tenantID = $global:tenantID
write-host "$tenantName`n$($tenantId)"

# 00000003 == MSGraph, 00000002 == AADGraph
$requiredResourceAccess=@"
[
    {
        "resourceAppId": "00000003-0000-0000-c000-000000000000",
        "resourceAccess": [
                {
					"id": "cefba324-1a70-4a6e-9c1d-fd670b7ae392",
					"type": "Scope"
				},
				{
					"id": "19dbc75e-c2e2-444c-a770-ec69d8559fc7",
					"type": "Role"
				},
				{
					"id": "62a82d76-70ea-41e2-9197-370581804d09",
					"type": "Role"
				},
				{
					"id": "5b567255-7703-4780-807c-7be8301ae99b",
					"type": "Role"
				},
				{
					"id": "1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9",
					"type": "Role"
				},
				{
					"id": "df021288-bdef-4463-88db-98f22de89214",
					"type": "Role"
				},
				{
					"id": "246dd0d5-5bd0-4def-940b-0421030a5b68",
					"type": "Role"
				},
				{
					"id": "79a677f7-b79d-40d0-a36a-3e6f8688dd7a",
					"type": "Role"
				},
				{
					"id": "fff194f1-7dce-4428-8301-1badb5518201",
					"type": "Role"
				},
				{
					"id": "4a771c9a-1cf2-4609-b88e-3d3e02d539cd",
					"type": "Role"
				}        ]
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
]
"@ | ConvertFrom-json

write-host "`nCreating WebApp $DisplayName..."

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
    $app = New-AzureADApplication -DisplayName $DisplayName -IdentifierUris "http://$TenantName/$DisplayName" -ReplyUrls @("https://$DisplayName") -RequiredResourceAccess $reqAccess
    write-output "AppID`t`t$($app.AppId)`nObjectID:`t$($App.ObjectID)"

    write-host "`nCreating ServicePrincipal..."
    $sp = New-AzureADServicePrincipal -AccountEnabled $true -AppId $App.AppId -AppRoleAssignmentRequired $false -DisplayName $DisplayName 
    write-host "AppID`t`t$($sp.AppId)`nObjectID:`t$($sp.ObjectID)"

    write-host "`nCreating App Key / Secret / client_secret - please remember this value and keep it safe"
    $AppSecret = New-AzureADApplicationPasswordCredential -ObjectId $App.ObjectID
    $AppSecretValue = $AppSecret.Value
} else {
    $AppSecretValue = (New-Guid).Guid.ToString()

    $app = (az ad app create --display-name $DisplayName --password $AppSecretValue --identifier-uris "http://$TenantName/$DisplayName" --reply-urls "https://$DisplayName" | ConvertFrom-json)
    write-output "AppID`t`t$($app.AppId)`nObjectID:`t$($App.ObjectID)"

    write-host "`nCreating ServicePrincipal..."
    $sp = (az ad sp create --id $app.appId | ConvertFrom-json)
    write-host "AppID`t`t$($sp.AppId)`nObjectID:`t$($sp.ObjectID)"

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

write-output "setting ENVVAR B2CAppID=$($App.AppId)"
$env:B2CAppId=$App.AppId
write-output "setting ENVVAR B2CAppKey=$($AppSecretValue)"
$env:B2CAppKey=$AppSecretValue

if ( $CreateConfigFile ) {
    $path = (get-location).Path
    $cfg = (Get-Content "$path\b2cAppSettings.json" | ConvertFrom-json)
    $cfg.ClientCredentials.client_id = $App.AppId
    $cfg.ClientCredentials.client_secret = $AppSecretValue
    $cfg.TenantName = $tenantName
    $ConfigFile = "$path\b2cAppSettings_" + $tenantName.split(".")[0] + ".json"
    Set-Content -Path $ConfigFile -Value ($cfg | ConvertTo-json) 
    write-output "Saved to config file $ConfigFile"
} else {
    write-output "Copy-n-paste this to your b2cAppSettings.json file `
    `"ClientCredentials`": { `
        `"client_id`": `"$($App.AppId)`", `
        `"client_secret`": `"$($AppSecretValue)`" `
    },"
}
