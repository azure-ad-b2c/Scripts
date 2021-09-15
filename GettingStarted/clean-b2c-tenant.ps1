#
# CAREFUL! 
# This script is intended to reset a B2C demo environment
# It deletes IEF Keys, IEF Policies, Users (excl GlobalAdmins), Groups and Applications (excl b2c-extensions-app)
#
exit # safety switch

$auth =Connect-AzureADB2CDevicelogin -TenantID $global:TenantName -Scope "TrustFrameworkKeySet.ReadWrite.All Policy.ReadWrite.TrustFramework Application.ReadWrite.All User.ReadWrite.All Group.ReadWrite.All"
$authHeader =@{ 'Content-Type'='application/json'; 'Authorization'=$auth.token_type + ' ' + $auth.access_token }

# delete all IEF Policy Keys
$url = "https://graph.microsoft.com/beta/trustFramework/keySets"
$resp = Invoke-RestMethod -Method GET -Uri $url -Headers $authHeader  
foreach( $pkey in $resp.value ) {
     $ret = Invoke-RestMethod -Method "DELETE" -Uri "$url/$($pkey.id)" -Headers $authHeader  
}

# delete all IEF Custom Policies
$url = "https://graph.microsoft.com/beta/trustFramework/policies"
$resp = Invoke-RestMethod -Method GET -Uri $url -Headers $authHeader  
foreach( $p in $resp.value ) {
     $ret = Invoke-RestMethod -Method "DELETE" -Uri "$url/$($p.id)" -Headers $authHeader  
}

# get all Global Admins (so we don't delete them)
$url = "https://graph.microsoft.com/beta/directoryRoles?`$filter=displayName eq 'Global Administrator'"
$resp = Invoke-RestMethod -Method GET -Uri $url -Headers $authHeader  
$idGlobalAdmin = $resp.value.id

$url = "https://graph.microsoft.com/beta/directoryRoles/$idGlobalAdmin/members"
$resp = Invoke-RestMethod -Method GET -Uri $url -Headers $authHeader  
$globalAdmins = $resp.value

# delete all users EXCEPT admins (otherwise you would be locked out)
$url = "https://graph.microsoft.com/beta/users"
$resp = Invoke-RestMethod -Method GET -Uri $url -Headers $authHeader  
foreach( $u in $resp.value ) {
    # don't delete Admins
    # if ( !($u.UserPrincipalName.IndexOf("#EXT#") -gt 0 -or $u.UserPrincipalName.StartsWith("graphexplorer@") -eq $True) ) {
    if ( $null -eq ( Compare-Object -IncludeEqual -ExcludeDifferent $u.id $globalAdmins.id) ) {
        $ret = Invoke-RestMethod -Method "DELETE" -Uri "$url/$($u.id)" -Headers $authHeader  
    } else {
        write-host "Skipping Global Admin " $u.id $u.displayName 
    }
}

# delete all groups
$url = "https://graph.microsoft.com/beta/groups"
$resp = Invoke-RestMethod -Method GET -Uri $url -Headers $authHeader  
foreach( $g in $resp.value ) {
    $ret = Invoke-RestMethod -Method "DELETE" -Uri "$url/$($g.id)" -Headers $authHeader  
}

# delete all applications
$url = "https://graph.microsoft.com/beta/applications"
$resp = Invoke-RestMethod -Method GET -Uri $url -Headers $authHeader  
foreach( $a in $resp.value ) {
    if ( !$a.displayName.StartsWith("b2c-extensions-app")) { # do NOT delete this app
        $ret = Invoke-RestMethod -Method "DELETE" -Uri "$url/$($a.id)" -Headers $authHeader  
    }
}
