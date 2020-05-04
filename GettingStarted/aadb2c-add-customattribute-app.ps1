param (
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",    
    [Parameter(Mandatory=$false)][Alias('c')][string]$client_id = "",    # client_id/AppId of the app handeling custom attributes
    [Parameter(Mandatory=$false)][Alias('a')][string]$objectId = "",     # objectId of the same app
    [Parameter(Mandatory=$false)][Alias('n')][string]$AppDisplayName = ""     # objectId of the same app
    )
   
if ( "" -eq $PolicyPath ) {
    $PolicyPath = (get-location).Path
}
    
[xml]$ext =Get-Content -Path "$PolicyPath\TrustFrameworkExtensions.xml" -Raw

$tpId = "AAD-Common"
$claimsProviderXml=@"
<ClaimsProvider>
  <DisplayName>Azure Active Directory</DisplayName>
  <TechnicalProfiles>
    <TechnicalProfile Id="AAD-Common">
      <Metadata>
        <!--Insert b2c-extensions-app application ID here, for example: 11111111-1111-1111-1111-111111111111-->  
        <Item Key="{client_id}"></Item>
        <!--Insert b2c-extensions-app application ObjectId here, for example: 22222222-2222-2222-2222-222222222222-->
        <Item Key="{objectId}"></Item>
      </Metadata>
    </TechnicalProfile>
  </TechnicalProfiles> 
</ClaimsProvider>
"@

if ( $ext.TrustFrameworkPolicy.ClaimsProviders.InnerXml -imatch $tpId ) {
  write-output "TechnicalProfileId $tpId already exists in policy"
  exit 1
}

# if no client_id given, use the standard b2c-extensions-app
if ( "" -eq $client_id ) {
    write-output "Using $AppDisplayName"
    $appExt = Get-AzureADApplication -SearchString $AppDisplayName
    $client_id = $appExt.AppId   
    $objectId = $appExt.objectId   
}
write-output "Adding TechnicalProfileId $tpId"

$claimsProviderXml = $claimsProviderXml.Replace("{client_id}", $client_id)
$claimsProviderXml = $claimsProviderXml.Replace("{objectId}", $objectId)

$ext.TrustFrameworkPolicy.ClaimsProviders.innerXml = $ext.TrustFrameworkPolicy.ClaimsProviders.innerXml + $claimsProviderXml

$ext.Save("$PolicyPath\TrustFrameworkExtensions.xml")
