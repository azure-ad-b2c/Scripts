param (
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",    
    [Parameter(Mandatory=$true)][Alias('i')][string]$ProviderName = "",    # google, twitter, amazon, linkedid, AzureAD
    [Parameter(Mandatory=$false)][Alias('c')][string]$client_id = "",    # client_id/AppId o the IdpName
    [Parameter(Mandatory=$false)][Alias('a')][string]$AadTenantName = ""    # contoso.com or contoso
    )
   
if ( "" -eq $PolicyPath ) {
    $PolicyPath = (get-location).Path
}
    
if ( "" -eq $client_id ) {
  $client_id = ($global:b2cAppSettings.ClaimsProviders | where {$_.Name -eq $ProviderName }).client_id
}

if ( "" -eq $AadTenantName -and "azuread" -eq $ProviderName.ToLower() ) {
  $AadTenantName = ($global:b2cAppSettings.ClaimsProviders | where {$_.Name -eq $ProviderName }).DomainName
}

[xml]$base =Get-Content -Path "$PolicyPath/TrustFrameworkBase.xml" -Raw
[xml]$ext =Get-Content -Path "$PolicyPath/TrustFrameworkExtensions.xml" -Raw

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
  default { write-output "IdP name must be either or google, twitter, linkedin, amazon or msa"; exit 1 }
}

if ( $ext.TrustFrameworkPolicy.ClaimsProviders.InnerXml -imatch $tpId ) {
  if ( "Facebook-OAUTH" -eq $tpId) {
    write-output "Updating TechnicalProfileId $tpId"
    $ext.TrustFrameworkPolicy.InnerXml = $ext.TrustFrameworkPolicy.InnerXml.Replace( "facebook_clientid", $client_id) 
    $ext.Save("$PolicyPath/TrustFrameworkExtensions.xml")        
    exit 0
  }
  write-output "TechnicalProfileId $tpId already exists in policy"
  exit 1
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
