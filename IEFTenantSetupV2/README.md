# B2C Identity Experience Framework - Getting Started

## Purpose
Configures an existing Azure AD B2C tenant for use with Identity Experience Framework custom policies. Performs all
tasks defined in the [get started](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-get-started?tabs=applications)
document.

## Usage
The application is [deployed and ready to use](https://aka.ms/iefsetup):
1. Enter the name of your B2C tenant
2. Sign-in with an account with admin privileges in that tenant (account that was used to create the tenant has these by defualt)
3. AzureAD will ask you to consent to the application having the ability to create objects in your tenant (applications, keys, policies)
4. Once you consent, the application will check whether your tenant has all the objects named in the [*Get started*](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-get-started?tabs=applications)
5. If these objects, do not exists, the application will create them (2 applications, 2 service principals and two keys, upload all policies and test app registration)

Once done, you can use can explore all of our [samples](https://github.com/azure-ad-b2c/samples).

