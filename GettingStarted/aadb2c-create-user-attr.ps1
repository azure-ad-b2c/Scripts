param (
    [Parameter(Mandatory=$False)][Alias('o')][string]$AppDisplayName = "b2c-extensions-app", # use this for default 
    [Parameter(Mandatory=$True)][Alias('n')][string]$attributeName = "", 
    [Parameter(Mandatory=$False)][Alias('d')][string]$dataType = "String" # String, Boolean, Date
    )

$appExt = Get-AzureADApplication -SearchString $AppDisplayName

New-AzureADApplicationExtensionProperty -ObjectID $appExt.objectId -DataType $dataType -Name $attributeName -TargetObjects @("User") 

<#
# list all current extension attributes
Get-AzureADExtensionProperty
#>

<#
# remove a specific attribute
$fullAttrName = "extension_" + $appExt.AppId.Replace("-","") + "_$attributeName"
$attrObj = Get-AzureADExtensionProperty | where {$_.Name -eq $fullAttrName}
Remove-AzureADApplicationExtensionProperty -ObjectId $appExt.objectId -ExtensionPropertyId $attrObj.ObjectId
#>

<#
# set/get a users extension attribute
Set-AzureADUserExtension -ObjectId $User.ObjectId -ExtensionName $attrName -ExtensionValue "001002003"
Get-AzureADUserExtension -ObjectId $User.ObjectId 
#>


