# Az.ADB2C Powershell Module

This github repo contains a set of powershell script that help you to quickly setup an Azure AD B2C tenant and Custom Policies. If you are to set up a B2C tenant, you need to follow the guide on how to [Create an Azure Active Directory B2C tenant](https://docs.microsoft.com/en-us/azure/active-directory-b2c/tutorial-create-tenant). This leaves you with a basic tenant, but in order to install the Custom Policies, described in the documentation page [Get started with custom policies in Azure Active Directory B2C](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-get-started?tabs=applications#custom-policy-starter-pack), there are quite a few steps to complete. Although it is not complicated, it takes some time and involves som copy-n-pase, flickering between documentation pages, before you can test your first login. The powershell scripts in this repo are created with the aim of minimizing the time from setting up a B2C tenant to your first login.

## Update
The scripts have been updated to use the [Azure Az PowerShell module](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-6.4.0) in order to get cross platform support. It no longer uses `Azure CLI` for MacOS/Linux platforms.

For **MacOS**, you find instructions on how to install Powershell in this [link](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-macos?view=powershell-7).

For **Linux**, you find instructions on how to install Powershell [here](https://linuxhint.com/install_powershell_ubuntu/). 

Once you have `Powershell core` installed on your system, you need to install the `Azure Az` module. This works the same for Windows, Mac and Linux. 
On Mac/Linux, you start powershell in a terminal by running the `pwsh` command.

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
if ($null -eq (get-module Az.Accounts)) {
    Install-Module -Name Az.Accounts -Scope CurrentUser -Repository PSGallery -Force
    Import-Module -Name Az.Accounts
}
```

The powershell commands have changed naming convetion from `*-AzureADBC*` to `*-AzADB2C` and some commands have changed the verb, like `Connect-AzureADB2CEnv` is now named `Connect-AzADB2C`, and `Deploy-AzureADB2CPolicyToTenant` is now named `Import-AzADB2CPolicyToTenant`. 

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
import-module .\Az.ADB2C.psm1
```

### 2. Connect to your B2C tenant for the first time
This powershell module work with a combination of interactive login and client credentials to perform the operations. 
When you start with new B2C tenant, there is no AppReg for the client credentials and we need to start by setting that up.
Therefor, we need to run these to commands first. `Connect-AzADB2CDevicelogin` will sign you in to your tenant and request an access token
with the scope for creating this AppReg. Change ***yourtenant*** to your B2C tenant name and optionally name the AppReg for the client credentials app differently. 

When you run the device login command, it will copy the device code onto your clipboard and you can paste it into your browser with Ctrl+V. The rest of the signin depends on how you company have configured device login to work.
   
```Powershell
Connect-AzADB2CDevicelogin -TenantName "yourtenant.onmicrosoft.com" -Scope "Directory.ReadWrite.All"
```
```Powershell
New-AzADB2CGraphApp -n "B2C-Graph-App" -CreateConfigFile
```

The `-CreateConfigFile` switch will create a file named `b2cAppSettings_yourtenant.json` and copy in the AppID (client_id) and key (client_secret) into the file. If you don't pass the switch, you have to copy-n-paste the json output for "ClientCredentials" and update the b2cAppSettings.json file. Update the tenant name in b2cAppSettings.json too.

### 3. Grant permissions to ***B2C-Graph-App***
The command `New-AzADB2CGraphApp` creats an AppReg to be used for client credentials, but it does not grant permissions to it. You leed to login to [https://portal.azure.com/yourtenant.onmicrosoft.com](https://portal.azure.com/yourtenant.onmicrosoft.com) and grant admin consent under API permissions. If the `Grant admin consent` button is greyed out in the portal, just wait a few seconds and do a hard refresh in the browser.

![Permissions to Grant](media/01-permissions-to-grant.png)

### 4. Sign in again
After you have completed the above step, you need to reauthenticate in order to be able to complete the rest of the setup. You do not need to close the powershell session. Issuing the below command in the same powershell session is ok.

```Powershell
Connect-AzADB2C -ConfigPath .\b2cAppSettings_yourtenant.json
```

### 5. Enabling Configuration for Identity Experience Framework
A new B2C tenat needs to have its IEF confuguration setup. This involves creating the `signing` and `encryption` policy keys, registering the applications
`IdentityExperienceFramework` and `ProxyIdentityExperienceFramework`. This is explained the docs [custom policy get started](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-get-started#register-identity-experience-framework-applications). This is all done with the below powershell command. By specifying the `-n "ABC-WebApp` the command will register a test app that you can use to test your B2C Custom Policies with that redirects to `https://jwt.ms`. The `-f "abc123"` creates a nonsense Facebook app secret. This is useful if you will use the SocialAndLocalAccounts base file from the B2C Starter Pack since it is built with Facebook as a sample. It is a nonsense secret to only make the policies upload ok and if you plan to use Facebook social login, you must register a real app in Facebook and recreate the key.

```powershell
Enable-AzADB2CIdentityExperienceFramework -n "ABC-WebApp" -f "abc123"
```

### 6. (Optional) Create a Local Admin user
You might consider creating a local admin user for the purpose of having a local user with admin rights that you can use to login to [Microsoft Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer). The user principle name will be `graphexplorer@yourtenant.onmicrosoft.com`. Having a local admin user also protects you from being completly locked out from your tenant in case the account you created the tenant becomes unusable.

```powershell
New-AzADB2CLocalAdmin -u "graphexplorer" -RoleNames @("Global Administrator")
```

# Creating a new Custom Policy project

Once you have your B2C tenant setup, it is time to create some Custom Policies. Using these Powershell modules, you will have your first Custom Policies ready to test in under 5 minutes.
 
## Start a powershell session for you B2C tenant

Open a new Powershell command prompt and load the modules.

```Powershell
cd AzureAD-B2C-scripts
import-module .\Az.ADB2C.psm1
```

Then, run the cmdlet `Connect-AzADB2C` and specify your config file on the command line.

```Powershell
Connect-AzADB2C -ConfigPath .\b2cAppsettings_yourtenant.json
```

If you don't like the concept of working with client credentials, you can use the device login method and use you interactive user. 
In order to be able to upload your B2C Custom Policies, you would need to specify the correct scopes, like below. 

```powershell
Connect-AzADB2CDevicelogin -TenantName "yourtenant.onmicrosoft.com" -Scope "Application.Read.All Policy.ReadWrite.TrustFramework"
```

## Create a new B2C Custom Policy project
Azure AD B2C Custom Policies has a starter pack of configuration files located in this [github repo](https://github.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack). When you work with B2C Custom Policies, you normally download the Starter Pack of choice and open them in a text editor to make your configuration modifications. All this work has been compacted in to one powershell command that will do all this for you.

By running it with the `-PolicyPrefix` parameter, you will modify the PolicyId to become `B2C_1A_demo_TrustFrameworkExtension`, etc, which helps you having multiple policies in one tenant. 

```powershell
New-AzADB2CPolicyProject -PolicyPrefix "demo"
```

The default PolicyType is `SocialAndLocalAccounts` and if you would like to base your policies on another type, you specify that on the command line.

```powershell
New-AzADB2CPolicyProject -PolicyPrefix "demo" -PolicyType "SocialAndLocalAccountsWithMfa"
```

After you have run `New-AzADB2CPolicyProject`, you can directly push them to your tenant and test them

```powershell
Import-AzADB2CPolicyToTenant 
Test-AzADB2CPolicy -n "ABC-WebApp"-p .\SignUpOrSignin.xml
```

If you are in a dev/test cycle and want to speed up testing of your changes, you can add the app name in the config file `b2cAppSettings_yourtenant.json` and shorten the command to just have the `-p` argument.

```json
    "ClientCredentials": {
        "client_id": "....",
        "client_secret": "...."
    },

    "TestAppName": "ABC-WebApp",
    "SAMLTestAppName": "samltestapp2",
```

### Quickly create a test user
You can either user the B2C policy's signup functionality to create a test user or create one using the powershell command below. By specifying an empty role, you will create a B2C Local Account just as you would using the signup functionality in the user journey.

```powershell
New-AzADB2CLocalAdmin -u "alice@contoso.com" -DisplayName "Alice Contoso" -RoleNames @()
```

## Add a desktop link to 
If you want to create a Desktop link to launch a powershell window with the module already imported, you create a new link and specify the following.

| Command       | Description                                |
|-------------------|--------------------------------------------|
| Target | %SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -noexit -command import-module .\Az.ADB2C.psm1 |
| Start in | %USERPROFILE%\src\b2c\scripts |

## List of Commands

See Get-Help <command> for details

| Command       | Description                                |
|-------------------|--------------------------------------------|
| `Add-AzADB2CClaimsProvider` | Adds a ClaimsProvider configuration to the TrustFrameworkExtensions.xml file |
| `Add-AzADB2CSAML2Protocol` | Adds support for SAML to your policies |
| `Connect-AzADB2C` | Connects to an Azure AD B2C tenant and loads the config |
| `Connect-AzADB2CDeviceLogin` | Connects to an Azure AD B2C tenant using device login |
| `Enable-AzADB2CIdentityExperienceFramework` | Completes the configuration in the B2C tenant for Identity Experience Framework |
| `Get-AzADB2CCustomDomain` | Lists all available custom domain names for the current tenant. |                     
| `Get-AzADB2CExtensionAttributesForUser` | Get extension attributes for user |      
| `Get-AzADB2CPolicy` | Gets a B2C Custom Policy from the tenant policy store by PolicyId |
| `Get-AzADB2CPolicyTree` | Get the B2C Policy file inheritance tree and returns it as an object or draws it like a tree |
| `Get-AzADB2CStarterPack` | Downloads the Azure AD B2C Custom Policy [Starter Pack](https://github.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack) |                     
| `Get-AzADB2CTenantId` | Gets tenant aliases. TenantId to domain names |
| `Get-AzADB2CPolicyIds` | Lists B2C Custom Policies from the tenant policy |
| `Get-AzADB2CTenantRegion` | Gets the tenant region, like EU |
| `Import-AzADB2CHtmlContent` | Uploads files to Azure Blob Storage for use of custom html/css/javascript |
| `Import-AzADB2CPolicyToTenant` | Uploads B2C Custom Policies from local path to B2C tenant |                 
| `New-AzADB2CExtensionAttribute` | Registers an extension attribute in the B2C tenant |              
| `New-AzADB2CGraphApp` | Registers an application with needed Graph API Permissions for use with client credentials operations on B2C tenant |
| `New-AzADB2CIdentityExperienceFrameworkApps` | Register Identity Experience Framework Apps IdentityExperienceFramework and ProxyIdentityExperienceFramework |
| `New-AzADB2CLocalAdmin` | Registers a Local Admin user in the B2C tenant. This user is not a Signup user but a user given admin permissions in the tenant |
| `New-AzADB2CPolicyKey` | Registers a B2C IEF Policy Key |
| `New-AzADB2CPolicyProject` | Wrapper command that downloads the starter pack, auto-edit the details, prepares custom attributes, upgrades to lates html page versions and enables javascript and sets the AppInsight Instrumentation Key. |
| `New-AzADB2CTestApp` | Registeres a test webapp that can be used for testing B2C Custom Policies with. It redirects to jwt.ms |
| `Read-AzADB2CConfig` | Read-AzADB2CConfig |
| `Remove-AzADB2CPolicyFromTenant` | Deletes B2C Custom Policies from a B2C tenant |
| `Remove-AzADB2CExtensionAttribute` | Removes an extension attribute in the B2C tenant |
| `Repair-AzADB2CUserJourneyOrder` | Makes sure UserJourney Numbers are in sequence 1..n with no gaps ord duplicates |
| `Set-AzADB2CAppInsights` | Sets the AppInsign InstrumentationKey in all or one RelyingParty files in PolicyPath
| `Set-AzADB2CCustomAttributeApp` | Sets the AppID and objectId for extension attributes in the B2C Custom Policies |
| `Set-AzADB2CCustomizeUX` | Prepares the policies for UX customizations via setting page version to latest and enabling javascript |                     
| `Set-AzADB2CExtensionAttributeForUser` | Updates an extension attributes for user |       
| `Set-AzADB2CKmsi` | Adds KMSI (Keep me signed in) to the signin page |                
| `Set-AzADB2CLocalization` | Add Localization to Signup/Signin page |                
| `Set-AzADB2CPolicyDetails ` | Updates the policy file details to make them ready for upload to a specific tenant. You can also use this command to clean away details before sharing your policies. |                  
| `Start-AzADB2CPortal` | Starts the Azure Portal in the right b2C tenant and with the B2C panel active |                        
| `Test-AzADB2CPolicy` | Creates a working url for testing and launches a browser to test a B2C Custom Policy |
