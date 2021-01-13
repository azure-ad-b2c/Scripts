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
# since you don't have a config file yet, just specify the tenant name
Connect-AzureADB2CEnv -t "yourtenant"
```

### 3. Create a App Registration that can be used for authenticating via Client Credentials

```Powershell
New-AzureADB2CGraphApp -n "B2C-Graph-App" -CreateConfigFile
```

The `-CreateConfigFile` switch will create a file named `b2cAppSettings_yourtenant.json` and copy in the AppID (client_id) and key (client_secret) into the file. If you don't pass the switch, you have to copy-n-paste the json output for "ClientCredentials" and update the b2cAppSettings.json file. Update the tenant name in b2cAppSettings.json too.

### 4. Find the ***B2C-Graph-App*** in [https://portal.azure.com/yourtenant.onmicrosoft.com](https://portal.azure.com/yourtenant.onmicrosoft.com) and grant admin consent under API permissions

![Permissions to Grant](media/01-permissions-to-grant.png)

### 4. Enabling Configuration for Identity Experience Framework

A new B2C tenat needs to have its IEF confuguration setup. This involves creating the `signing` and `encryption` policy keys, registering the applications
`IdentityExperienceFramework` and `ProxyIdentityExperienceFramework`. This is explained the docs [custom policy get started](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-get-started#register-identity-experience-framework-applications). This is all done with the below powershell command. By specifying the `-n "ABC-WebApp` the command will register a test app that you can use to test your B2C Custom Policies with that redirects to `https://jwt.ms`. The `-f "abc123"` creates a nonsense Facebook app secret. This is useful if you will use the SocialAndLocalAccounts base file from the B2C Starter Pack since it is built with Facebook as a sample. It is a nonsense secret to only make the policies upload ok and if you plan to use Facebook social login, you must register a real app in Facebook and recreate the key.

```powershell
Enable-AzureADB2CIdentityExperienceFramework -n "ABC-WebApp" -f "abc123"
```

### 5. (Optional) Create a Local Admin user

You might consider creating a local admin user for the purpose of having a local user with admin rights that you can use to login to [Microsoft Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer). The user principle name will be `graphexplorer@yourtenant.onmicrosoft.com`. Having a local admin user also protects you from being completly locked out from your tenant in case the account you created the tenant becomes unusable.

```powershell
New-AzureADB2CLocalAdmin -u "graphexplorer" -RoleNames @("Company Administrator")
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
Connect-AzureADB2CEnv -ConfigPath .\b2cAppsettings_yourtenant.json
```
## Create a B2C Custom Policy project based on the B2C Starter Pack
Azure AD B2C Custom Policies has a starter pack of configuration files located in this [github repo](https://github.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack). When you work with B2C Custom Policies, you normally download the Starter Pack of choice and open them in a text editor to make your configuration modifications. All this work has been compacted in to one powershell command that will do all this for you.

By running it with the `-PolicyPrefix` parameter, you will modify the PolicyId to become `B2C_1A_demo_TrustFrameworkExtension`, etc, which helps you having multiple policies in one tenant. 

```powershell
New-AzureADB2CPolicyProject -PolicyPrefix "demo"
```

The default PolicyType is `SocialAndLocalAccounts` and if you would like to base your policies on another type, you specify that on the command line.

```powershell
New-AzureADB2CPolicyProject -PolicyPrefix "demo" -PolicyType "SocialAndLocalAccountsWithMfa"
```

After you have run ***New-AzureADB2CPolicyProject***, you can directly push them to your tenant and test them

```powershell
Deploy-AzureADB2CPolicyToTenant 

Test-AzureADB2CPolicy -n "ABC-WebApp"-p .\SignUpOrSignin.xml
```

## List of Commands

See Get-Help <command> for details

| Command       | Description                                |
|-------------------|--------------------------------------------|
| `Connect-AzureADB2CEnv` | Connects to an Azure AD B2C tenant and loads the config |
| `Delete-AzureADB2CPolicyFromTenant` | Deletes B2C Custom Policies from a B2C tenant |
| `Deploy-AzureADB2CHtmlContent` | Uploads files to Azure Blob Storage for use of custom html/css/javascript |
| `Deploy-AzureADB2CPolicyToTenant` | Uploads B2C Custom Policies from local path to B2C tenant |                 
| `Enable-AzureADB2CIdentityExperienceFramework` | Completes the configuration in the B2C tenant for Identity Experience Framework |
| `Get-AzureADB2CAccessToken` | Lists AzureAD's token cache |                     
| `Get-AzureADB2CCustomDomain` | Lists all available custom domain names for the current tenant. |                     
| `Get-AzureADB2CExtensionAttributesForUser` | Get extension attributes for user |      
| `Get-AzureADB2CPolicyId` | Gets a B2C Custom Policy from the tenant policy store by PolicyId |
| `Get-AzureADB2CStarterPack` | Downloads the Azure AD B2C Custom Policy [Starter Pack](https://github.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack) |                     
| `List-AzureADB2CPolicyIds` | Lists B2C Custom Policies from the tenant policy |
| `New-AzureADB2CExtensionAttribute` | Registers an extension attribute in the B2C tenant |              
| `New-AzureADB2CGraphApp` | Registers an application with needed Graph API Permissions for use with client credentials operations on B2C tenant |
| `New-AzureADB2CIdentityExperienceFrameworkApps` | Register Identity Experience Framework Apps IdentityExperienceFramework and ProxyIdentityExperienceFramework |
| `New-AzureADB2CLocalAdmin` | Registers a Local Admin user in the B2C tenant. This user is not a Signup user but a user given admin permissions in the tenant |
| `New-AzureADB2CPolicyKey` | Registers a B2C IEF Policy Key |
| `New-AzureADB2CPolicyProject` | Wrapper command that downloads the starter pack, auto-edit the details, prepares custom attributes, upgrades to lates html page versions and enables javascript and sets the AppInsight Instrumentation Key. |
| `New-AzureADB2CTestApp` | Registeres a test webapp that can be used for testing B2C Custom Policies with. It redirects to jwt.ms |
| `Read-AzureADB2CConfig` |                          Read-AzureADB2CConfig
| `Remove-AzureADB2CExtensionAttribute` | Removes an extension attribute in the B2C tenant |
| `Repair-AzureADB2CUserJourneyOrder` | Makes sure UserJourney Numbers are in sequence 1..n with no gaps ord duplicates |
| `Set-AzureADB2CAppInsights` | Sets the AppInsign InstrumentationKey in all or one RelyingParty files in PolicyPath
| `Set-AzureADB2CClaimsProvider` | Adds a ClaimsProvider configuration to the TrustFrameworkExtensions.xml file |
| `Set-AzureADB2CCustomAttributeApp` | Sets the AppID and objectId for extension attributes in the B2C Custom Policies |
| `Set-AzureADB2CCustomizeUX` | Prepares the policies for UX customizations via setting page version to latest and enabling javascript |                     
| `Set-AzureADB2CExtensionAttributeForUser` | Updates an extension attributes for user |       
| `Set-AzureADB2CGrantPermissions` | Grans Permission to a registered App |                
| `Set-AzureADB2CKmsi` | Adds KMSI (Keep me signed in) to the signin page |                
| `Set-AzureADB2CLocalization` | Add Localization to Signup/Signin page |                
| `Set-AzureADB2CPolicyDetails ` | Updates the policy file details to make them ready for upload to a specific tenant. You can also use this command to clean away details before sharing your policies. |                  
| `Start-AzureADB2CPortal` | Starts the Azure Portal in the right b2C tenant and with the B2C panel active |                        
| `Test-AzureADB2CPolicy` | Creates a working url for testing and launches a browser to test a B2C Custom Policy |
