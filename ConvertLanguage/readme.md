# Convert Language files using the Azure Cognative API 

## Community Help and Support
Use [Stack Overflow](https://stackoverflow.com/questions/tagged/azure-ad-b2c) to get support from the community. Ask your questions on Stack Overflow first and browse existing issues to see if someone has asked your question before. Make sure that your questions or comments are tagged with [azure-ad-b2c].
If you find a bug in the sample, please raise the issue on [GitHub Issues](https://github.com/azure-ad-b2c/samples/issues).
To provide product feedback, visit the Azure Active Directory B2C [Feedback page](https://feedback.azure.com/forums/169401-azure-active-directory?category_id=160596).

## Overview
Azure AD B2C currently supports [36 languages](https://docs.microsoft.com/en-gb/azure/active-directory-b2c/active-directory-b2c-reference-language-customization#supported-languages) out of the box. However if you language is not currently supported you have the ability to upload your own languages files, giving Azure AD B2C the ability to support **any** language.
for more information on Azure AD B2C Language customisation see the B2C Documetation pages - [Language customization in Azure Active Directory B2C](https://docs.microsoft.com/en-gb/azure/active-directory-b2c/active-directory-b2c-reference-language-customization)

This Powershell script uses [Azure Cognative API](https://www.microsoft.com/en-us/translator/) to translate the language file values from english to the specified language.
The example sets the language to New Zealand Māori (mi) as the language to convert to. Samples of the output can also be seen under the [Māori folder](/ConvertLanguage/Maori)

## How to run the script
1. First download the default language files from B2C (See [documentation](https://docs.microsoft.com/en-gb/azure/active-directory-b2c/active-directory-b2c-reference-language-customization#customize-your-strings))
1. Store the lange files in a single directory with the json file name prefix (eg DefaultLocalizedResources_api.selfasserted1.1_en.**json**)
1. There are 2 settings in the powershell file you need to change;
    1. $global:lan - Set this to your desired language to convert to (eg mi = Mauori)
    1. $global:APIKey - This is the Azure cognative services key. Form more information see their [documentation](https://docs.microsoft.com/en-us/azure/cognitive-services/translator/translator-text-how-to-signup)
1. Thats it

Then just run the sciript and it will allend the chosen language code to the new file names.
