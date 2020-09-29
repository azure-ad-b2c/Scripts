# B2C Identity Experience Framework - getting started

## Purpose
Configures an existing B2C tenant for use with Identity Experience Framework custom policies. Performs all
tasks defined in the [get started](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-get-started?tabs=applications)
document **except** [creating a Facebook signing key](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-get-started?tabs=applications#create-the-facebook-key) 
required by some [starter policies](https://github.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack).

## Usage
The application is [deployed and ready to use](https://b2ciefsetup.azurewebsites.net):
1. Enter the name of your B2C tenant
2. Sign-in with an account with admin privileges in that tenant (account that was used to create the tenant has these by defualt)
3. AzureAD will ask you to consent to the application having the ability to create objects in your tenant (applications, keys)
4. Once you consent, the application will check whether your tenant has all the objects named in the [*Get started*](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-get-started?tabs=applications)
5. If these objects, do not exists, the application will create them (2 applications, 2 service principals and two keys)
6. The final screen will display the relevant application ids needed in the IEF policies. 
7. If the application did not exist already, the final screen will provide a url link you should use to complete
admin consent for the new applications to use each other [item 9 in the Get started](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-get-started?tabs=applications#register-the-proxyidentityexperienceframework-application)
8. You can use the Enterprise Apps option of the Azure portal's AAD blade to remove the B2CIEFSetup service principal
from your tenant (optional).

Once done, you can use some [PowerShell tools](https://github.com/mrochon/b2cief-upload) to prepare your policies, edit them
using VS Code with the [B2C extension](https://github.com/azure-ad-b2c/vscode-extension) and upload them to the B2C tenant.

