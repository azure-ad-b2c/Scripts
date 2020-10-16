# AzureAD-B2C-scripts

This github repo contains a set of powershell script that help you to quickly setup an Azure AD B2C tenant and Custom Policies. If you are to set up a B2C tenant, you need to follow the guide on how to [Create an Azure Active Directory B2C tenant](https://docs.microsoft.com/en-us/azure/active-directory-b2c/tutorial-create-tenant). This leaves you with a basic tenant, but in order to install the Custom Policies, described in the documentation page [Get started with custom policies in Azure Active Directory B2C](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-get-started?tabs=applications#custom-policy-starter-pack), there are quite a few steps to complete. Although it is not complicated, it takes some time and involves som copy-n-pase, flickering between documentation pages, before you can test your first login. The powershell scripts in this repo are created with the aim of minimizing the time from setting up a B2C tenant to your first login.

## Update
The scripts have been updated to support running on Mac/Linux. In order to run them on MacOS, you need to install both Azure CLI and Powershell Core, then start the powershell command prompt with the pwsh command.

Install [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-macos) on MacOS.

Install [Powershell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-macos?view=powershell-7) on MacOS.

# Setting up a new B2C tenant

With the scripts in this repository, you can create a fully functional B2C Custom Policy environment in seconds via the commands 

## Prerequisites

As mentioned, you need to [create your B2C tenant](https://docs.microsoft.com/en-us/azure/active-directory-b2c/tutorial-create-tenant) which involves creating the resource in [portal.azure.com](https://portal.azure.com)

![Create B2C Tenant](https://docs.microsoft.com/en-us/azure/active-directory-b2c/media/tutorial-create-tenant/portal-02-create-tenant.png)

After creating the tenant, you need to link it to your Azure Subscription

![Linking the B2C tenant](https://docs.microsoft.com/en-us/azure/active-directory-b2c/media/tutorial-create-tenant/portal-05-link-subscription.png)

## Starting from scratch

### 1. Open a powershell command prompt and git clone this repo 

```Powershell
git clone https://github.com/cljung/AzureAD-B2C-scripts.git
cd AzureAD-B2C-scripts
import-module .\AzureADB2C-Scripts.psm1
```

### 2. Connect to you B2C tenant

```Powershell
Connect-AzureADB2CEnv -t "yourtenant"
```

### 3. Create a App Registration that can be used for authenticating via Client Credentials

```Powershell
.\aadb2c-create-graph-app.ps1 -n "B2C-Graph-App" -CreateConfigFile
```

The `-CreateConfigFile` switch will create a file named `b2cAppSettings_yourtenant.json` and copy in the AppID (client_id) and key (client_secret) into the file. If you don't pass the switch, you have to copy-n-paste the json output for "ClientCredentials" and update the b2cAppSettings.json file. Update the tenant name in b2cAppSettings.json too.

### 4. Find the ***B2C-Graph-App*** in [https://portal.azure.com/yourtenant.onmicrosoft.com](https://portal.azure.com/yourtenant.onmicrosoft.com) and grant admin consent under API permissions

![Permissions to Grant](media/01-permissions-to-grant.png)

### 5. Create Custom Policy Keys

In the [custom policy get started](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-get-started#add-signing-and-encryption-keys) documentation, it describes that you need to create your token encryption and signing keys. This isn't the most tedious job and doing it by hand is quite fast, but if you want to automate it, the following two lines will do it for you. 

If you **haven't** created these two keys in the portal already, you can create them by running the below command. If you **have** created them, skip this.

```Powershell
New-AzureADB2CPolicyKey -KeyContainerName "B2C_1A_TokenSigningKeyContainer" -KeyType "RSA" -KeyUse "sig"
New-AzureADB2CPolicyKey -KeyContainerName "B2C_1A_TokenEncryptionKeyContainer" -KeyType "RSA" -KeyUse "enc"
```

### 6. Create the Custom Policy apps IdentityExperienceFramework and ProxyIdentityExperienceFramework

In the [custom policy get started](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-get-started#register-identity-experience-framework-applications) documentation, it describes that you need to register two applications to sign up and sign in local accounts. If you **haven't** registered these two apps in the portal already, you can do that by running the below command. If you **have** registered them, skip this.

```Powershell
New-AzureADB2CIdentityExperienceFrameworkApps
```

### 7. Create an App Registration for a test webapp that accepts https://jwt.ms as redirectUri

To test the Custom Policy you need to register a dummy webapp in the portal that you can use. This is described in the tutorial for how to register an app and can be found here under section [Register a web application](https://docs.microsoft.com/en-us/azure/active-directory-b2c/tutorial-register-applications?tabs=app-reg-preview#register-a-web-application). The script will register a WebApp in your B2C tenant that redirects to http://jwt.ms. 

```Powershell
New-AzureADB2CTestApp -n "Test-WebApp"
```

This command may fail on granting permissions. This will happen if you haven't given your graph app (the one you created above with aadb2c-create-graph-app.ps1) the permission Directory.ReadWrite.All. In that case, go to portal.azure.com and manually grant the app the permissions.

If the graph app do not have the Application.ReadWrite.All permission, it will fail updating the manifest settings and you are better of deleting the app and to redo this step after you have given the graph app the Application.ReadWrite.All permission.

### 8. Create Facebook secret

Even though you might not use social login via Facebook, quite alot in the Custom Policies from the Starter Pack requires the key to be there for the policies to upload without error, so create a dummy key for now.

```powershell
New-AzureADB2CPolicyKey -KeyContainerName "B2C_1A_FacebookSecret" -KeyType "secret" -KeyUse "sig" -Secret "abc123"
``` 

# Creating a new Custom Policy project

Once you have your B2C tenant setup, it is time to create some Custom Policies. Using these Powershell modules, you will have your first Custom Policies ready to test in under 5 minutes.
 
## Start a powershell session for you B2C tenant

Open a new Powershell command prompt and load the modules.

```Powershell
cd AzureAD-B2C-scripts
import-module .\AzureADB2C-Scripts.psm1
```

Then, run the cmdlet ***Connect-AzureADB2CEnv***. This cmdlet either accepts a tenant name or the path to your b2cAppSettings.json file. If you run it with the ***-t "yourtenant"*** switch, you then need to run ***Read-AzureADB2CConfig*** at some later stage to load the settings you have in your b2cAppSettings.json file.

```Powershell
Connect-AzureADB2CEnv -ConfigPath .\b2cAppsettings.json
# or
Connect-AzureADB2CEnv -t "yourtenant"
```
## The easy way - New-AzureADB2CPolicyProject
The cmdlet ***New-AzureADB2CPolicyProject*** is a wrapper that will execute the following cmdlets if you prefer to quickly get going and accept all defaults.

So by running this command
```powershell
New-AzureADB2CPolicyProject -PolicyPrefix "demo"
```

you are effectivly executing this sequence of commands, which means you will download the Starter Pack, change it to work against your tenant, add b2c-extensions-app as the app for custom attributes, add AppInsight instrumentation and switch to version 1.2.0 of the UX so you are ready to go ***if*** you decide you need javascript later.
```powershell
    Get-AzureADB2CStarterPack 
    Set-AzureADB2CPolicyDetails -PolicyPrefix "X2"
    Set-AzureADB2CCustomAttributeApp 
    Set-AzureADB2CAppInsights 
    Set-AzureADB2CCustomizeUX 
```
After you have run ***New-AzureADB2CPolicyProject***, you can directly push them to your tenant and test them (see Push-AzureADB2CPolicyToTenant below)

## Download the Custom Policy Starter Pack and modify them to your tenant

These 4 cmdlets will download the B2C Starter Pack files, wire them up to your tenant and make them ready for deployment. The first two are mandatory, the second two is likely that you want to use. 

```Powershell
md demo; cd demo
Get-AzureADB2CStarterPack               # get the starter pack from github
Set-AzureADB2CPolicyDetails -x "demo"   # set the tenant details and give the policies the "demo" prefix
Set-AzureADB2CCustomAttributeApp        # set the custom attribute app to 'b2c-extensions'
Set-AzureADB2CCustomizeUX               # set UX version to ver 1.2 to enable javascript
```

The output will look something like this

```powershell
PS C:\Users\cljung\src\b2c\scripts\demo> Get-AzureADB2CStarterPack                                                   Downloading https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/SocialAndLocalAccounts/TrustFrameworkBase.xml to C:\Users\cljung\src\b2c\scripts\demo/TrustFrameworkBase.xml
Downloading https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/SocialAndLocalAccounts/TrustFrameworkExtensions.xml to C:\Users\cljung\src\b2c\scripts\demo/TrustFrameworkExtensions.xml
Downloading https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/SocialAndLocalAccounts/SignUpOrSignin.xml to C:\Users\cljung\src\b2c\scripts\demo/SignUpOrSignin.xml
Downloading https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/SocialAndLocalAccounts/PasswordReset.xml to C:\Users\cljung\src\b2c\scripts\demo/PasswordReset.xml
Downloading https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/SocialAndLocalAccounts/ProfileEdit.xml to C:\Users\cljung\src\b2c\scripts\demo/ProfileEdit.xml
PS C:\Users\cljung\src\b2c\scripts\scratch> Set-AzureADB2CPolicyDetails -x "demo"                                       Tenant:         cljungscratchb2c.onmicrosoft.com
TenantID:       a81...48a
Getting AppID's for IdentityExperienceFramework / ProxyIdentityExperienceFramework
Getting AppID's for b2c-extensions-app
dff...a58
Modifying Policy file PasswordReset.xml...
Modifying Policy file ProfileEdit.xml...
Modifying Policy file SignUpOrSignin.xml...
Modifying Policy file TrustFrameworkBase.xml...
Modifying Policy file TrustFrameworkExtensions.xml...
Facebook
Local Account SignIn
PS C:\Users\cljung\src\b2c\scripts\demo> Set-AzureADB2CCustomAttributeApp                                            Using b2c-extensions-app
Adding TechnicalProfileId AAD-Common
PS C:\Users\cljung\src\b2c\scripts\demo> Set-AzureADB2CCustomizeUX
```

## Upload the Custom Policies to your tenant

```Powershell
Push-AzureADB2CPolicyToTenant           # upload the policies
```

The output will look something like this

```Powershell
PS C:\Users\cljung\src\b2c\scripts\demo> Push-AzureADB2CPolicyToTenant                                               Tenant:         cljungscratchb2c.onmicrosoft.com
TenantID:       a81...48a
Authenticating as App B2C-Graph-App, AppID 63f...71f
Uploading policy B2C_1A_demo_TrustFrameworkBase...
http://cljungscratchb2c.onmicrosoft.com/B2C_1A_demo_TrustFrameworkBase
Uploading policy B2C_1A_demo_TrustFrameworkExtensions...
http://cljungscratchb2c.onmicrosoft.com/B2C_1A_demo_TrustFrameworkExtensions
Uploading policy B2C_1A_demo_PasswordReset...
http://cljungscratchb2c.onmicrosoft.com/B2C_1A_demo_PasswordReset
Uploading policy B2C_1A_demo_ProfileEdit...
http://cljungscratchb2c.onmicrosoft.com/B2C_1A_demo_ProfileEdit
Uploading policy B2C_1A_demo_signup_signin...
http://cljungscratchb2c.onmicrosoft.com/B2C_1A_demo_signup_signin
```

## Testing the Custom Policies 

The cmdlet ***Test-AzureADB2CPolicy*** will read the Relying Party xml file, query the tenant for the App Registration and assemble a url to the authorization endpoint and then launch the browser to test the policy.
 
```Powershell
Test-AzureADB2CPolicy -n "Test-WebApp" -p .\SignUpOrSignin.xml
```

# b2cAppSettings.json file 

The config file [b2cAppSettings.json](b2cAppSettings.json) contains settings for your environment and also what features you would like in your Custom Policy. It contains the following elements

* top element - contains a few settings, like which B2C Starter Pack you want to use. The default is ***SocialAndLocalAccounts***

* ClientCredentials - the client credentials we are going to use when we do GraphAPI calls, like uploading the Custom POlicy xml files

* AzureStorageAccount - Azure Blob Storage account settings. You will need this if you opt-in to to UX customizaion as the html files will be stored in blob storage. 

* CustomAttributes - if you plan to use custom attributes, you need to specify which App Registration will handle the custom attributes in the policy. The default is the "b2c-extension-app"

* UxCustomization - If you enable this, the script will download the template html files from your B2C tenant into a subfolder called "html" and upload them to Azure Blob Storage. The policy file ***TrustFrameworkExtension.xml*** will be updated to point to your storage for the url's to the html

* ClaimsProviders - a list of claims provider you like to support. Note that for each you enable, you need to use the respective portal to configure your app and to copy-n-paste the client_id/secret into b2cAppSettings.json

If you just want to test drive the below step, enable the Facebook Claims Provider (Enable=true) and set the client_id + client_secret configuration values to something bogus, like 1234567890. Since Facebook is part of the Starter Pack to begin with, you need this to be enabled to be able to upload correctly. Later if you want to use Facebook, you can register a true app and change the key or you can remove the Facebook Claims Provider in the ***TrustFrameworkExtension.xml*** file.

# Cmdlets Reference

## Get-AzureADB2CStarterPack 

Downloads the Starter Pack Custom Policy files from github.

```powershell
NAME
    Get-AzureADB2CStarterPack
    
SYNTAX
    Get-AzureADB2CStarterPack [[-PolicyPath] <string>] [[-PolicyType] <string>] [<CommonParameters>]
```
- PolicyPath (p) : where you want to store the downloaded Starter Pack files. Default is current directory
- PolicyType (b) : What type of policies to download. Default is SocialAndLocalAccounts. Valid values are any folder in the Starter Pack github repo, like SocialAndLocalAccountsWithMfa, etc.

## Set-AzureADB2CPolicyDetails

Updates the Custom Policy files with your tenant name, your IdentityExperience Framework/ProxyIdentityExperienceFramework AppIDs and objectIds, optionally modifies the policy names with unique prefix.

```powershell
NAME
    Set-AzureADB2CPolicyDetails
    
SYNTAX
    Set-AzureADB2CPolicyDetails [[-TenantName] <string>] [[-PolicyPath] <string>] [[-PolicyPrefix] <string>] [[-IefAppName] <string>] [[-IefProxyAppName] <string>] [[-ExtAppDisplayName] <string>] [[-AzureCli] <bool>] [<CommonParameters>]
```

- TenantName (t)   : if you want to override the current tenant you are working in when updating the policies
- PolicyPath (p)   : where you want to store the downloaded Starter Pack files. Default is current directory
- PolicyPrefix (x) : If you want the policyIds to have a unique name, like B2C_1A_***demo***_signup_signin
- IefAppName       : if the IdentityExperienceFramework app should have another name (there is no reason why but testing)
- IefProxyAppName  : if the ProxyIdentityExperienceFramework app should have another name (there is no reason why but testing)
- ExtAppDisplayName : The app DisplayName of the app to use for custom attributes (default is b2c-extensions-app). This value is only used if TechnicalProfile AAD-Common is already present in the file. To add AAD-Common, use Set-AzureADB2CCustomAttributeApp cmdlets.
- AzureCLI         : if to force the usage of Azure CLI on Windows platform

## Set-AzureADB2CCustomizeUX 

Updates the Custom Policy files with UX template settings, enables javascript and optionally prepares the fils for custom html.

```powershell
NAME
    Set-AzureADB2CCustomizeUX
    
SYNTAX
    Set-AzureADB2CCustomizeUX [[-PolicyPath] <string>] [[-RelyingPartyFileName] <string>] [[-BasePolicyFileName] <string>] [[-ExtPolicyFileName] <string>] [[-
    DownloadHtmlTemplates] <bool>] [[-urlBaseUx] <string>] [<CommonParameters>]
```

- PolicyPath (p)   : where you want to store the downloaded Starter Pack files. Default is current directory
- RelyingPartyFileName (r) : if to just update one file. Default is enumerate all policy files
- BasePolicyFileName (b) : Name of TrustFrameworkBase.xml file, if named differently
- ExtPolicyFileName (e) : Name of TrustFramworkExtensions.xml file, if named differently
- DownloadHtmlTemplates (d) : if to download the Azure Ocean blue standard html templates so you can have them as a starting point for making your own custom html
- urlBaseUx (u) : If to replace the url links in TrustFrameworkExtensions.xml with your own links to your custom html

## Push-AzureADB2CPolicyToTenant 

Uploads Custom Policy file(s) to your tenant, overwriting existing versions

```powershell
NAME
    Push-AzureADB2CPolicyToTenant
    
SYNTAX
    Push-AzureADB2CPolicyToTenant [[-PolicyPath] <string>] [[-PolicyFile] <string>] [[-TenantName] <string>] [[-AppID] <string>] [[-AppKey] <string>] [[-Azure
    Cli] <bool>] [<CommonParameters>]
 ```

- PolicyPath (p)   : where you want to store the downloaded Starter Pack files. Default is current directory
- PolicyFile (f)   : if to upload a single file. Default is all files
- TenantName (t)   : if to override the default tenant you are working in
- AppID (a)        : AppId (client_id) of B2C-Graph-App or App that has the Policy.ReadWrite.TrustFramework permission
- AppKey (k)       : client_secret for the above app
- AzureCLI         : if to force the usage of Azure CLI on Windows platform

## Test-AzureADB2CPolicy

```powershell
NAME
    Test-AzureADB2CPolicy
    
SYNTAX
    Test-AzureADB2CPolicy [-PolicyFile] <string> [-WebAppName] <string> [[-redirect_uri] <string>] [[-scopes] <string>] [[-AzureCli] <bool>] [<CommonParameter
    s>]
```

- PolicyFile (p)   : RelyingParty Custom Policy file to use, like ./SignupOrSignin.xml
- WebAppName (n)   : DisplayName of the webapp to use, like Test-WebApp
- redirect_uri (r) : Redirect uri to use. Default is https://jwt.ms
- scopes (s)       : additional scopes to add. You don't need to specify openid offline_access
- AzureCLI         : if to force the usage of Azure CLI on Windows platform

## Delete-AzureADB2CPolicyFromTenant

Enumerates all policy files in directory and deletes the policy in the tenant

```powershell
NAME
    Delete-AzureADB2CPolicyFromTenant
    
SYNTAX
    Delete-AzureADB2CPolicyFromTenant [[-PolicyPath] <string>] [[-PolicyFile] <string>] [[-TenantName] <string>] [[-AppID] <string>] [[-AppKey] <string>] [[-A
    zureCli] <bool>] [<CommonParameters>]
```

- PolicyPath (p)   : where you want to store the downloaded Starter Pack files. Default is current directory
- PolicyFile (f)   : if to upload a single file. Default is all files
- TenantName (t)   : if to override the default tenant you are working in
- AppID (a)        : AppId (client_id) of B2C-Graph-App or App that has the Policy.ReadWrite.TrustFramework permission
- AppKey (k)       : client_secret for the above app
- AzureCLI         : if to force the usage of Azure CLI on Windows platform

## Set-AzureADB2CClaimsProvider

Adds Claims Provider config to your TrustFrameworkExtensions.xml file. If you want to add Azure AD, Google, MSA, Linkedin, etc, quickly, this cmdlet is for you.

```powershell
NAME
    Set-AzureADB2CClaimsProvider
    
SYNTAX
    Set-AzureADB2CClaimsProvider [[-PolicyPath] <string>] [-ProviderName] <string> [[-client_id] <string>] [[-AadTenantName] <string>] [[-BasePolicyFileName] 
    <string>] [[-ExtPolicyFileName] <string>] [<CommonParameters>]
```

- PolicyPath (p)   : where you want to store the downloaded Starter Pack files. Default is current directory
- ProviderName (i) : must be either or google, twitter, linkedin, amazon, facebook, azuread or msa
- client_id (c)    : client_id for the provider. If not specified, value in b2cAppSettings.json is used
- AadTenantName (a): For Azure AD you need to specify contoso.com, etc
- BasePolicyFileName (b) : name of trustFrameworkBase.xml, if named differently
- ExtPolicyFileName (e) : name of TrustFrameworkExtensions.xml, if named differently

## Read-AzureADB2CConfig

Loads the settings in the b2cAppSettings.json file. This is done automatically if you connect with Connect-AzureADB 2CEnv using the -ConfigPath file. But if you didn't or have changed some settings, this is how your reload it.

```powershell
NAME
    Read-AzureADB2CConfig
    
SYNTAX
    Read-AzureADB2CConfig [[-TenantName] <string>] [[-PolicyPath] <string>] [[-PolicyPrefix] <string>] [[-KeepPolicyIds] <bool>] [-ConfigPath] <string> [[-Azu
    reCli] <bool>] [<CommonParameters>]
```

## Set-AzureADB2CAppInsights

Adds the needed config in the RelyingParty files for sending events to AppInsights. This is really useful for troubleshooting a Custom Policy.

```powershell
NAME
    Set-AzureADB2CAppInsights
    
SYNTAX
    Set-AzureADB2CAppInsights [[-PolicyPath] <string>] [[-PolicyFile] <string>] [[-InstrumentationKey] <string>] [<CommonParameters>]
```

## New-AzureADB2CTestApp

Creates an App Registration for a test webapp that you c an use to test your Custom Policies.

```powershell
NAME
    New-AzureADB2CTestApp
    
SYNTAX
    New-AzureADB2CTestApp [-DisplayName] <string> [[-AppID] <string>] [[-AppKey] <string>] [[-AzureCli] <bool>] [<CommonParameters>]
```

## Set-AzureADB2CGrantPermissions

Helper cmdlet that grants permission to an App Registration. Only needed on the Windows platform as az cli has built in support for this.

```powershell
NAME
    Set-AzureADB2CGrantPermissions
    
SYNTAX
    Set-AzureADB2CGrantPermissions [[-TenantName] <string>] [[-AppID] <string>] [[-AppKey] <string>] [-AppDisplayName] <string> [<CommonParameters>]
```

## Get-AzureADB2CAccessToken

Gets your access token from your local cache. Windows only