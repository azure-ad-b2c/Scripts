param (
    [Parameter(Mandatory=$false)][Alias('n')][string]$DisplayName = "B2C-Graph-App"
    )

write-host "Getting Tenant info..."
$tenant = Get-AzureADTenantDetail
$tenantName = $tenant.VerifiedDomains[0].Name
write-host "$tenantName`n$($tenant.ObjectId)"

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
                "id": "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30",
                "type": "Role"
            },
            {
                "id": "1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9",
                "type": "Role"
            },
            {
                "id": "7ab1d382-f21e-4acd-a863-ba3e13f7da61",
                "type": "Role"
            },
            {
                "id": "19dbc75e-c2e2-444c-a770-ec69d8559fc7",
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
]
"@ | ConvertFrom-json

$reqAccess=@()
foreach( $resApp in $requiredResourceAccess ) {
    $req = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
    $req.ResourceAppId = $resApp.resourceAppId
    foreach( $ra in $resApp.resourceAccess ) {
        $req.ResourceAccess += New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList $ra.Id,$ra.type
    }
    $reqAccess += $req
}

write-host "`nCreating WebApp $DisplayName..."
$app = New-AzureADApplication -DisplayName $DisplayName -IdentifierUris "http://$TenantName/$DisplayName" -ReplyUrls @("https://$DisplayName") -RequiredResourceAccess $reqAccess
write-output "AppID`t`t$($app.AppId)`nObjectID:`t$($App.ObjectID)"

write-host "`nCreating ServicePrincipal..."
$sp = New-AzureADServicePrincipal -AccountEnabled $true -AppId $App.AppId -AppRoleAssignmentRequired $false -DisplayName $DisplayName 
write-host "AppID`t`t$($sp.AppId)`nObjectID:`t$($sp.ObjectID)"

write-host "`nCreating App Key / Secret / client_secret - please remember this value and keep it safe"
$AppSecret = New-AzureADApplicationPasswordCredential -ObjectId $App.ObjectID

write-output "Copy and paste this to your b2cAppSettings.json file `
`"ClientCredentials`": { `
    `"client_id`": `"$($App.AppId)`", `
    `"client_secret`": `"$($AppSecret.Value)`" `
},"

write-output "setting ENVVAR B2CAppID=$($App.AppId)"
$env:B2CAppId=$App.AppId
write-output "setting ENVVAR B2CAppKey=$($AppSecret.Value)"
$env:B2CAppKey=$AppSecret.Value

write-output "Remember to go to portal.azure.com for the app and Grant Permissions"
