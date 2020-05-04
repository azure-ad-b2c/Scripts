param (
    [Parameter(Mandatory=$false)][Alias('t')][string]$TenantName = "",
    [Parameter(Mandatory=$false)][Alias('d')][string]$displayName = "GraphExplorer",
    [Parameter(Mandatory=$false)][Alias('u')][string]$username = "graphexplorer",
    [Parameter(Mandatory=$false)][Alias('p')][string]$Password = "",
    [Parameter(Mandatory=$false)][Alias('r')][string[]]$RoleNames = @("Directory Readers", "Directory Writers") # @("Company Administrator") for Global Admin
    )

if ( "" -eq $TenantName ) {
    write-host "Getting Tenant info..."
    $tenant = Get-AzureADTenantDetail
    if ( $null -eq $tenant ) {
        write-host "Not logged in to a B2C tenant"
        exit 1
    }
    $tenantName = $tenant.VerifiedDomains[0].Name
    $tenantID = $tenant.ObjectId
}

$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
if ( "" -eq $Password ) {
    $cred = Get-Credential -UserName $DisplayName -Message "Enter userid for $TenantName"
    $PasswordProfile.Password = $cred.GetNetworkCredential().Password
} else {
    $PasswordProfile.Password = $Password
}
$PasswordProfile.ForceChangePasswordNextLogin = $false

$user = New-AzureADUser -DisplayName $displayName -mailNickName $username -PasswordPolicies "DisablePasswordExpiration" `
                -UserType "Member" -AccountEnabled $true -PasswordProfile $PasswordProfile -UserPrincipalName "$username@$tenantName"
write-output "User`t`t$username`nObjectID:`t$($user.ObjectID)"

foreach( $roleName in $RoleNames) {
    $role = Get-AzureADDirectoryRole | Where-Object {$_.displayName -eq $roleName}
    if ( $null -eq $role ) {
        $roleTemplate = Get-AzureADDirectoryRoleTemplate | ? { $_.DisplayName -eq $roleName }
        $ret = Enable-AzureADDirectoryRole -RoleTemplateId $roleTemplate.ObjectId        
        $role = Get-AzureADDirectoryRole | Where-Object {$_.displayName -eq $roleName}
    }
    $ret = Add-AzureADDirectoryRoleMember -ObjectId $role.ObjectId -RefObjectId $user.ObjectId
    write-output "Role`t`t$($role.DisplayName)`nDescription:`t$($role.Description)"
}
