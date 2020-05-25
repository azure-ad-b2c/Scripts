param (
    [Parameter(Mandatory=$true)][Alias('g')][string]$GroupName = "",
    [Parameter(Mandatory=$false)][Alias('e')][string]$email = ""
    )

$user = Get-AzureADUser -Filter "signInNames/any(x:x/value eq '$email')" -ErrorAction SilentlyContinue
if ( $null -eq $user ) {
    write-error "User with signInName email=$email not found"
    exit 1
}
$group = Get-AzureADGroup -SearchString $GroupName -ErrorAction SilentlyContinue
if ( $null -eq $group ) {
    write-host "Createing group $GroupName"
    $group = New-AzureADGroup -DisplayName $GroupName -MailEnabled $False -SecurityEnabled $True -MailNickName $GroupName 
}
$ret = Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $user.ObjectId
Get-AzureADGroupMember -ObjectId $group.objectId
