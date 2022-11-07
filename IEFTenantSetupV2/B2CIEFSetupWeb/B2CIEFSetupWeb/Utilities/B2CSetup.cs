using B2CIEFSetupWeb.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Identity.Web;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Xml;
using System.Xml.Linq;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;

namespace B2CIEFSetupWeb.Utilities
{
    public interface IB2CSetup
    {
        Task<List<IEFObject>> SetupAsync(string domainId, bool readOnly, string dirDomainName, bool initialisePhoneSignInJourneys, string PolicySample, bool enableJS);
    }
    public class B2CSetup : IB2CSetup
    {

        private TelemetryClient telemetry = new TelemetryClient();
        private readonly ITokenAcquisition _tokenAcquisition;
        private readonly ILogger<B2CSetup> _logger;
        private HttpClient _http;
        public B2CSetup(ILogger<B2CSetup> logger, ITokenAcquisition tokenAcquisition)
        {
            _logger = logger;
            _tokenAcquisition = tokenAcquisition;
        }
        public string DomainName { get; private set; }
        private bool _readOnly = false;
        private bool _removeFb = false;
        private bool _enableJS = false;
        public string PolicySample { get; private set; }
        public async Task<List<IEFObject>> SetupAsync(string domainId, bool removeFb, string dirDomainName, bool initialisePhoneSignInJourneys, string PolicySample, bool enableJS)
        {

            using (_logger.BeginScope("SetupAsync: {0} - Read only: {1}", domainId, removeFb))
            {
                telemetry.InstrumentationKey = "a1dfc418-6ff5-4662-a7a1-f2faa979e74f";
                _actions = new List<IEFObject>();
                if (PolicySample != "null")
                {
                    var startProperties = new Dictionary<string, string>
                        {{"Result", "Success"}};
                    // Send the event:
                    telemetry.Context.Operation.Name = "Deploy Sample Policy"; 
                    telemetry.TrackEvent("Start deployment", startProperties);
                    bool usingSample = true;
                    var token = await _tokenAcquisition.GetAccessTokenOnBehalfOfUserAsync(
                        Constants.ReadWriteScopes,
                        domainId);
                    _http = new HttpClient();
                    _http.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

                    HttpClient _httpToRepoAPI = new HttpClient();
                    string urlToFetchPolices = "https://gitrepomanager.azurewebsites.net/api/FetchRepo?policyname=" + PolicySample;
                    var json = await _httpToRepoAPI.GetStringAsync(urlToFetchPolices);
                    var value = JArray.Parse(json);

                    var rawPolicyFileNames = new List<string>();
                    foreach (string url in value)
                    {
                        rawPolicyFileNames.Add(url);
                    }
                    //if we found ext file, move to top
                    var regexExtensions = @"\w*Extensions\w*";
                    var indexExtensions = -1;
                    indexExtensions = rawPolicyFileNames.FindIndex(d => regexExtensions.Any(s => Regex.IsMatch(d.ToString(), regexExtensions)));
                    if (indexExtensions > -1)
                    {
                        rawPolicyFileNames.Insert(0, rawPolicyFileNames[indexExtensions]);
                        rawPolicyFileNames.RemoveAt(indexExtensions + 1);
                    }
                    //if we found base file, move to top
                    var regexBase = @"\w*Base\w*";
                    var indexBase = -1;
                    indexBase = rawPolicyFileNames.FindIndex(d => regexBase.Any(s => Regex.IsMatch(d.ToString(), regexBase)));
                    if (indexBase > -1)
                    {
                        rawPolicyFileNames.Insert(0, rawPolicyFileNames[indexBase]);
                        rawPolicyFileNames.RemoveAt(indexBase + 1);
                    }
                    var policyFileList = new List<string>();

                    foreach (string url in rawPolicyFileNames) {                     
                        policyFileList.Add(new WebClient().DownloadString(url));
                        }

                    for (int i = 0; i < policyFileList.Count; i++)
                    {
                        policyFileList[i] = policyFileList[i].Replace("yourtenant.onmicrosoft.com", dirDomainName + ".onmicrosoft.com");
                    }


                    //build k-v pair list of policyId:policyFilen
                    var policyList = buildPolicyListByPolicyId(policyFileList);
                    await UploadPolicyFiles(policyList, usingSample, PolicySample);

                    var endSampleUploadProperties = new Dictionary<string, string>
                        {{"Result", "Success"}};
                    // Send the event:
                    telemetry.Context.Operation.Name = "Deploy Sample Policy";
                    telemetry.TrackEvent("Completed deployment", endSampleUploadProperties);

                    return _actions;
                }


                if (PolicySample == "null") { 
                    _removeFb = removeFb;
                    _enableJS = enableJS;

                    
                    // Set up some properties and metrics:
                    var startProperties = new Dictionary<string, string>
                        {{"Result", "Success"}};
                    // Send the event:
                    telemetry.Context.Operation.Name = "Deploy Starter Pack";
                    telemetry.TrackEvent("Started Starter Pack deployment", startProperties);

                    try
                    {
                        var token = await _tokenAcquisition.GetAccessTokenOnBehalfOfUserAsync(
                            Constants.ReadWriteScopes,
                            domainId);
                        _http = new HttpClient();
                        _http.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

                    
                        await SetupIEFAppsAsync(domainId);
                        await SetupKeysAsync();
                        var extAppId = await GetAppIdAsync("b2c-extensions-app");
                        _actions.Add(new IEFObject()
                        {
                            Name = "Extensions app: appId",
                            Id = extAppId,
                            Status = String.IsNullOrEmpty(extAppId) ? IEFObject.S.NotFound : IEFObject.S.Exists
                        });
                        extAppId = await GetAppIdAsync("b2c-extensions-app", true);
                        _actions.Add(new IEFObject()
                        {
                            Name = "Extensions app: objectId",
                            Id = extAppId,
                            Status = String.IsNullOrEmpty(extAppId) ? IEFObject.S.NotFound : IEFObject.S.Exists
                        });
                    } catch (Exception ex)
                    {
                        _logger.LogError(ex, "SetupAsync failed");
                    }


                    //actions structure
                    //ief app 0
                    //proxyief app 1
                    //extension appid 4
                    //extension objectId 5


                    //download localAndSocialStarterPack
                    // returns list policyId: policyXML
                    var policyList = GetPolicyFiles(removeFb, dirDomainName, initialisePhoneSignInJourneys);

                    // Strip UJs from SocialLocalMFA base file
                    // Take UJs from Local base file and put it in Extensions file

                    if (removeFb)
                    {
                        // Remove default social and local and mfa user journeys
                        XmlDocument socialAndLocalBase = new XmlDocument();
                        socialAndLocalBase.LoadXml(policyList.First(kvp => kvp.Key == "B2C_1A_TrustFrameworkBase").Value);
                        var nsmgr = new XmlNamespaceManager(socialAndLocalBase.NameTable);
                        nsmgr.AddNamespace("xsl", "http://schemas.microsoft.com/online/cpim/schemas/2013/06");

                        XmlNode socialAndMFAJourneys = socialAndLocalBase.SelectSingleNode("/xsl:TrustFrameworkPolicy/xsl:UserJourneys", nsmgr);
                        socialAndMFAJourneys.RemoveAll();
                        XmlNode parentSocialAndMFAJourneys = socialAndMFAJourneys.ParentNode;
                        parentSocialAndMFAJourneys.RemoveChild(socialAndMFAJourneys);

                        XmlNode facebookTP = socialAndLocalBase.SelectSingleNode("/xsl:TrustFrameworkPolicy/xsl:ClaimsProviders/xsl:ClaimsProvider[1]", nsmgr);
                        facebookTP.RemoveAll();
                        XmlNode parentfacebookTP = facebookTP.ParentNode;
                        parentfacebookTP.RemoveChild(facebookTP);

                        //policyList.RemoveAll(kvp => kvp.Key == "B2C_1A_TrustFrameworkBase");
                        policyList["B2C_1A_TrustFrameworkBase"] = socialAndLocalBase.OuterXml;
                        //policyList.Add(new KeyValuePair<string, string>("B2C_1A_TrustFrameworkBase", socialAndLocalBase.OuterXml));

                        // Insert user journeys from LocalAccounts base file into Ext file.
                        XmlDocument localBase = new XmlDocument();
                        //string baseFileLocal = new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/tree/localization/LocalAccounts/TrustFrameworkBase.xml");
                        string baseFileLocal = new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/LocalAccounts/TrustFrameworkBase.xml");
                        localBase.LoadXml(baseFileLocal);
                        XmlNode localBaseJourneys = localBase.SelectSingleNode("/xsl:TrustFrameworkPolicy/xsl:UserJourneys", nsmgr);

                        string localJourneysString = localBaseJourneys.OuterXml;
                        localJourneysString.Replace("<UserJourneys xmlns=\"http://schemas.microsoft.com/online/cpim/schemas/2013/06\">", "<UserJourneys>");
                        string extFile = policyList.First(kvp => kvp.Key == "B2C_1A_TrustFrameworkExtensions").Value;
                        extFile = extFile.Replace("</TrustFrameworkPolicy>", localJourneysString + "</TrustFrameworkPolicy>");
                        extFile.Replace("yourtenant.onmicrosoft.com", dirDomainName + ".onmicrosoft.com");

                        //policyList.RemoveAll(kvp => kvp.Key == "B2C_1A_TrustFrameworkExtensions");
                        //policyList.Add(new KeyValuePair<string, string>("B2C_1A_TrustFrameworkExtensions", extFile));

                        policyList["B2C_1A_TrustFrameworkExtensions"] = extFile;

                    }

                    // setup login-noninteractive and ext attribute support
                    policyList = SetupAADCommon(policyList, initialisePhoneSignInJourneys);

                    if (_enableJS) { policyList = EnableJavascript(policyList, initialisePhoneSignInJourneys); }
                    

                    if (!removeFb)
                    {
                        await SetupDummyFacebookSecret(removeFb);
                    }
                    else
                    {
                        _actions.Add(new IEFObject()
                        {
                            Name = "Facebook secret",
                            Id = "B2C_FacebookSecret",
                            Status = IEFObject.S.Skipped
                        });
                    }

                    await UploadPolicyFiles(policyList, false, "");
                    await CreateJwtMsTestApp();
                } 
            }
            var endProperties = new Dictionary<string, string>
                        {{"Result", "Success"}};
            // Send the event:
            telemetry.Context.Operation.Name = "Deploy Starter Pack";
            telemetry.TrackEvent("Completed Starter Pack deployment", endProperties);
            return _actions;
        }
        public List<IEFObject> _actions;
        public SetupState _state;



        private Dictionary<string, string> GetPolicyFiles(bool removeFb, string dirDomainName, bool initialisePhoneSignInJourneys)
        {

            var policyFileList = new List<string>();
            policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/localization/SocialAndLocalAccounts/TrustFrameworkBase.xml"));

            if (!removeFb)
            {
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/SocialAndLocalAccounts/TrustFrameworkLocalization.xml"));
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/SocialAndLocalAccounts/TrustFrameworkExtensions.xml"));                
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/SocialAndLocalAccounts/SignUpOrSignin.xml"));
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/SocialAndLocalAccounts/PasswordReset.xml"));
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/SocialAndLocalAccounts/ProfileEdit.xml"));
            }
            if (removeFb)
            {
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/LocalAccounts/TrustFrameworkLocalization.xml"));
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/LocalAccounts/TrustFrameworkExtensions.xml"));
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/LocalAccounts/SignUpOrSignin.xml"));
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/LocalAccounts/PasswordReset.xml"));
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/LocalAccounts/ProfileEdit.xml"));
            }

            if (initialisePhoneSignInJourneys)
            {
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/scenarios/phone-number-passwordless/Phone_Email_Base.xml"));
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/scenarios/phone-number-passwordless/ChangePhoneNumber.xml"));
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/scenarios/phone-number-passwordless/ProfileEditPhoneEmail.xml"));
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/scenarios/phone-number-passwordless/ProfileEditPhoneOnly.xml"));
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/scenarios/phone-number-passwordless/SignUpOrSignInWithPhone.xml"));
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/scenarios/phone-number-passwordless/SignUpOrSignInWithPhoneOrEmail.xml"));
                policyFileList.Add(new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/scenarios/phone-number-passwordless/PasswordResetEmail.xml"));

            }

            for (int i = 0; i < policyFileList.Count; i++)
            {
                policyFileList[i] = policyFileList[i].Replace("yourtenant.onmicrosoft.com", dirDomainName + ".onmicrosoft.com");
                //policyFileList[i] = policyFileList[i].Replace("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>", "");                
            }

            //build k-v pair list of policyId:policyFilen
            var policyList = buildPolicyListByPolicyId(policyFileList);

            return policyList;
        }

        private Dictionary<string, string> buildPolicyListByPolicyId(List<string> policyFileList)
        {

            var policyList = new Dictionary<string, string>();
            foreach (string policyFile in policyFileList)
            {

                XDocument policyFileDoc = XDocument.Parse(policyFile);
                string policyFileDocPolicyId = policyFileDoc.Root.Attribute("PolicyId").Value;
                policyList.Add(policyFileDocPolicyId, policyFile);
            }

            return policyList;
        }


        private async Task SetupIEFAppsAsync(string domainId)
        {
            var AppName = "IdentityExperienceFramework";
            var ProxyAppName = "ProxyIdentityExperienceFramework";

            var json = await _http.GetStringAsync("https://graph.microsoft.com/beta/domains");
            var value = (JArray)JObject.Parse(json)["value"];
            DomainName = ((JObject)value.First())["id"].Value<string>();
            _logger.LogTrace("Domain: {0}", DomainName);
            //TODO: needs refactoring

            _actions.Add(new IEFObject()
            {
                Name = AppName,
                Status = IEFObject.S.NotFound
            });
            _actions[0].Id = await GetAppIdAsync(_actions.First(kvp => kvp.Name == "IdentityExperienceFramework").Name);
            if (!String.IsNullOrEmpty(_actions[0].Id)) {
                // here we should PATCH the object to repair it
                _actions[0].Status = IEFObject.S.Exists; 
            }
            _actions.Add(new IEFObject()
            {
                Name = ProxyAppName,
                Status = IEFObject.S.NotFound
            });
            _actions[1].Id = await GetAppIdAsync(_actions.First(kvp => kvp.Name == "ProxyIdentityExperienceFramework").Name);
            if (!String.IsNullOrEmpty(_actions[1].Id)) { 
                // here we should PATCH the object to repair it
                _actions[1].Status = IEFObject.S.Exists; 
            }

            if (!String.IsNullOrEmpty(_actions[0].Id) && !String.IsNullOrEmpty(_actions[1].Id)) return; // Sorry! What if only one exists?
            //TODO: should verify whether the two apps are setup correctly
            if (_readOnly) return;

            var requiredAADAccess = new
            {
                resourceAppId = "00000002-0000-0000-c000-000000000000",
                resourceAccess = new List<object>()
            {
                new {
                    id = "311a71cc-e848-46a1-bdf8-97ff7156d8e6",
                    type = "Scope"
                }
            }
            };
            var iefApiPermission = new
            {
                adminConsentDescription = $"Allow the application to access {AppName} on behalf of the signed-in user.",
                adminConsentDisplayName = $"Access {AppName}",
                id = Guid.NewGuid().ToString("D"),
                isEnabled = true,
                type = "User",
                userConsentDescription = $"Allow the application to access {AppName} on your behalf.",
                userConsentDisplayName = $"Access {AppName}",
                value = "user_impersonation"
            };

            var app = new
            {
                isFallbackPublicClient = false,
                displayName = AppName,
                identifierUris = new List<string>() { $"https://{DomainName}/{AppName}" },
                signInAudience = "AzureADMyOrg",
                api = new { oauth2PermissionScopes = new List<object> { iefApiPermission } },
                web = new
                {
                    redirectUris = new List<string>() { $"https://login.microsoftonline.com/{DomainName}" },
                    homePageUrl = $"https://login.microsoftonline.com/{DomainName}",
                    implicitGrantSettings = new
                    {
                        enableIdTokenIssuance = true,
                        enableAccessTokenIssuance = false
                    }
                }
            };

            json = JsonConvert.SerializeObject(app);
            var resp = await _http.PostAsync($"https://graph.microsoft.com/beta/applications",
                new StringContent(json, Encoding.UTF8, "application/json"));
            if (resp.IsSuccessStatusCode)
            {
                _logger.LogTrace("{0} application created", AppName);
                var body = await resp.Content.ReadAsStringAsync();
                var appJSON = JObject.Parse(body);
                _actions[0].Id = (string)appJSON["appId"];
                _actions[0].Status = IEFObject.S.New;
                var spId = Guid.NewGuid().ToString("D");
                var sp = new
                {
                    accountEnabled = true,
                    appId = _actions.First(kvp => kvp.Name == "IdentityExperienceFramework").Id,
                    appRoleAssignmentRequired = false,
                    displayName = AppName,
                    homepage = $"https://login.microsoftonline.com/{DomainName}",
                    replyUrls = new List<string>() { $"https://login.microsoftonline.com/{DomainName}" },
                    servicePrincipalNames = new List<string>() {
                    app.identifierUris[0],
                    _actions.First(kvp => kvp.Name == "IdentityExperienceFramework").Id
                },
                    tags = new string[] { "WindowsAzureActiveDirectoryIntegratedApp" },
                };
                resp = await _http.PostAsync($"https://graph.microsoft.com/beta/servicePrincipals",
                    new StringContent(JsonConvert.SerializeObject(sp), Encoding.UTF8, "application/json"));
                if (!resp.IsSuccessStatusCode) throw new Exception(resp.ReasonPhrase);
                _logger.LogTrace("{0} SP created", AppName);
            }

            var proxyApp = new
            {
                isFallbackPublicClient = true,
                displayName = ProxyAppName,
                signInAudience = "AzureADMyOrg",
                publicClient = new { redirectUris = new List<string>() { $"https://login.microsoftonline.com/{DomainName}" } },
                parentalControlSettings = new { legalAgeGroupRule = "Allow" },
                requiredResourceAccess = new List<object>() {
                new {
                    resourceAppId = _actions.First(kvp => kvp.Name == "IdentityExperienceFramework").Id,
                    resourceAccess = new List<object>()
                    {
                        new {
                            id = iefApiPermission.id,
                            type = "Scope"
                        }
                    }
                },
                new {
                    resourceAppId = "00000002-0000-0000-c000-000000000000",
                    resourceAccess = new List<object>()
                    {
                        new
                        {
                            id = "311a71cc-e848-46a1-bdf8-97ff7156d8e6",
                            type = "Scope"
                        }
                    }
                }
            },
                web = new
                {
                    implicitGrantSettings = new
                    {
                        enableIdTokenIssuance = true,
                        enableAccessTokenIssuance = false
                    }
                }
            };

            json = JsonConvert.SerializeObject(proxyApp);
            resp = await _http.PostAsync($"https://graph.microsoft.com/beta/applications",
                new StringContent(json, Encoding.UTF8, "application/json"));
            if (resp.IsSuccessStatusCode)
            {
                _logger.LogTrace("{0} app created", ProxyAppName);
                var body = await resp.Content.ReadAsStringAsync();
                var appJSON = JObject.Parse(body);
                _actions[1].Id = (string)appJSON["appId"];
                _actions[1].Status = IEFObject.S.New;
                var sp = new
                {
                    accountEnabled = true,
                    appId = _actions.First(kvp => kvp.Name == "ProxyIdentityExperienceFramework").Id,
                    appRoleAssignmentRequired = false,
                    displayName = ProxyAppName,
                    //homepage = $"https://login.microsoftonline.com/{DomainName}",
                    //publisherName = DomainNamePrefix,
                    replyUrls = new List<string>() { $"https://login.microsoftonline.com/{DomainName}" },
                    servicePrincipalNames = new List<string>() {
                    _actions.First(kvp => kvp.Name == "ProxyIdentityExperienceFramework").Id
                },
                    tags = new string[] { "WindowsAzureActiveDirectoryIntegratedApp" },
                };
                resp = await _http.PostAsync($"https://graph.microsoft.com/beta/servicePrincipals",
                    new StringContent(JsonConvert.SerializeObject(sp), Encoding.UTF8, "application/json"));
                if (!resp.IsSuccessStatusCode) throw new Exception(resp.ReasonPhrase);
                //AdminConsentUrl = new Uri($"https://login.microsoftonline.com/{tokens.TenantId}/oauth2/authorize?client_id={appIds.ProxyAppId}&prompt=admin_consent&response_type=code&nonce=defaultNonce");
                _logger.LogTrace("{0} SP created", AppName);
            }

            return;
        }

        private async Task UploadPolicyFiles(Dictionary<string, string> policyFileList, bool usingSample, string sampleName)
        {
            foreach (KeyValuePair<string, string> policy in policyFileList)
            {

                XDocument policyFile = XDocument.Parse(policy.Value);
                string policyFileId = policyFile.Root.Attribute("PolicyId").Value;
                var resp = await _http.PutAsync($"https://graph.microsoft.com/beta/trustFramework/policies/" + policyFileId + "/$value",
                new StringContent(policy.Value, Encoding.UTF8, "application/xml"));
                //UploadError contents = (UploadError)JsonConvert.DeserializeObject(await resp.Content.ReadAsStringAsync());
                var respContents = await resp.Content.ReadAsStringAsync();
                
                if (resp.IsSuccessStatusCode)
                {
                    _actions.Add(new IEFObject()
                    {
                        Name = "Policy",
                        Id = policyFileId,
                        Status = IEFObject.S.Uploaded
                    });
                    if (usingSample)
                    {
                        // Set up some properties and metrics:
                        var properties = new Dictionary<string, string>
                        {{"PolicyName", sampleName}, {"Result", "Success"}};
                        // Send the event:
                        telemetry.Context.Operation.Name = "Deploy Sample Policy";
                        telemetry.TrackEvent("Sample Policy upload", properties);
                    }

                }
                if (!resp.IsSuccessStatusCode)
                {
                    UploadError error = JsonConvert.DeserializeObject<UploadError>(respContents);
                    _actions.Add(new IEFObject()
                    {
                        Name = "Policy",
                        Id = policyFileId,
                        Status = IEFObject.S.Failed,
                        Reason = error.error.message
                    });
                    if (usingSample)
                    {
                        // Set up some properties and metrics:
                        var properties = new Dictionary<string, string>
                        {{"PolicyFolder", sampleName}, {"Result", "Failure"}, {"Error", error.error.message}};
                        // Send the event:
                        telemetry.Context.Operation.Name = "Deploy Sample Policy";
                        telemetry.TrackEvent("Sample Policy upload", properties);
                    }
                }
            }
        }
        private Dictionary<string, string> EnableJavascript(Dictionary<string, string> policyList, bool initialisePhoneSignInJourneys)
        {
            string jsContentDefinitions = @"    
                            <ContentDefinitions>
                              <ContentDefinition Id=""api.error"">
                                <DataUri>urn:com:microsoft:aad:b2c:elements:contract:globalexception:1.2.0</DataUri>
                              </ContentDefinition>
                              <ContentDefinition Id=""api.idpselections"">
                                <DataUri>urn:com:microsoft:aad:b2c:elements:contract:providerselection:1.2.0</DataUri>
                              </ContentDefinition>
                              <ContentDefinition Id=""api.idpselections.signup"">
                                <DataUri>urn:com:microsoft:aad:b2c:elements:contract:providerselection:1.2.0</DataUri>
                              </ContentDefinition>
                              <ContentDefinition Id=""api.signuporsignin"">
                                <DataUri>urn:com:microsoft:aad:b2c:elements:contract:unifiedssp:2.1.1</DataUri>
                              </ContentDefinition>
                              <ContentDefinition Id=""api.selfasserted"">
                                <DataUri>urn:com:microsoft:aad:b2c:elements:contract:selfasserted:2.1.1</DataUri>
                              </ContentDefinition>
                              <ContentDefinition Id=""api.selfasserted.profileupdate"">
                                <DataUri>urn:com:microsoft:aad:b2c:elements:contract:selfasserted:2.1.1</DataUri>
                              </ContentDefinition>
                              <ContentDefinition Id=""api.localaccountsignup"">
                                <DataUri>urn:com:microsoft:aad:b2c:elements:contract:selfasserted:2.1.1</DataUri>
                              </ContentDefinition>
                              <ContentDefinition Id=""api.localaccountpasswordreset"">
                                <DataUri>urn:com:microsoft:aad:b2c:elements:contract:selfasserted:2.1.1</DataUri>
                              </ContentDefinition>
                              <ContentDefinition Id=""api.phonefactor"">
                                <DataUri>urn:com:microsoft:aad:b2c:elements:contract:multifactor:1.2.0</DataUri>
                              </ContentDefinition>
                            </ContentDefinitions>
                        </BuildingBlocks>";

            string extFile = policyList.First(kvp => kvp.Key == "B2C_1A_TrustFrameworkExtensions").Value;

            extFile = extFile.Replace("</BuildingBlocks>", jsContentDefinitions);
            policyList["B2C_1A_TrustFrameworkExtensions"] = extFile;

            return policyList;

        }
            private Dictionary<string, string> SetupAADCommon(Dictionary<string, string> policyList, bool initialisePhoneSignInJourneys)
            {

            string extFile = policyList.First(kvp => kvp.Key == "B2C_1A_TrustFrameworkExtensions").Value;

            extFile = extFile.Replace("ProxyIdentityExperienceFrameworkAppId", _actions.First(kvp => kvp.Name == "ProxyIdentityExperienceFramework").Id);
            extFile = extFile.Replace("IdentityExperienceFrameworkAppId", _actions.First(kvp => kvp.Name == "IdentityExperienceFramework").Id);

            if (initialisePhoneSignInJourneys)
            {
                string phoneFile = policyList.First(kvp => kvp.Key == "B2C_1A_Phone_Email_Base").Value;

                phoneFile = phoneFile.Replace("ProxyIdentityExperienceFrameworkAppId", _actions.First(kvp => kvp.Name == "ProxyIdentityExperienceFramework").Id);
                phoneFile = phoneFile.Replace("IdentityExperienceFrameworkAppId", _actions.First(kvp => kvp.Name == "IdentityExperienceFramework").Id);
                phoneFile = phoneFile.Replace("{insert your privacy statement URL}", "https://myprivacycontenturl.com");
                phoneFile = phoneFile.Replace("{insert your terms and conditions URL}", "https://mytermsofuseurl.com");
                policyList["B2C_1A_Phone_Email_Base"] = phoneFile;

            }

            string aadCommon = @"    
                            <ClaimsProviders>
                             <ClaimsProvider>
                              <DisplayName>Azure Active Directory</DisplayName>
                              <TechnicalProfiles>
                                <TechnicalProfile Id=""AAD-Common"">
                                  <DisplayName>Azure Active Directory</DisplayName>
                                  <Metadata>
                                    <Item Key=""ApplicationObjectId"">ExtAppObjectId</Item>
                                    <Item Key=""ClientId"">ExtAppId</Item>
                                  </Metadata>
                                </TechnicalProfile>
                              </TechnicalProfiles>
                            </ClaimsProvider>";

            aadCommon = aadCommon.Replace("ExtAppObjectId", _actions.First(kvp => kvp.Name == "Extensions app: objectId").Id);
            aadCommon = aadCommon.Replace("ExtAppId", _actions.First(kvp => kvp.Name == "Extensions app: appId").Id);

            extFile = extFile.Replace("<ClaimsProviders>", aadCommon);

            //policyList.RemoveAll(kvp => kvp.Key == "B2C_1A_TrustFrameworkExtensions");
            //policyList.Add(new KeyValuePair<string, string>("B2C_1A_TrustFrameworkExtensions", extFile));

            policyList["B2C_1A_TrustFrameworkExtensions"] = extFile;           

            return policyList;
        }

        private async Task CreateJwtMsTestApp()
        {
            var iefTestApp = new
            {
                isFallbackPublicClient = false,
                identifierUris = new List<string>() { $"https://{DomainName}/IEFTestApp" },
                displayName = "IEF Test App",
                signInAudience = "AzureADandPersonalMicrosoftAccount",
                parentalControlSettings = new { legalAgeGroupRule = "Allow" },
                requiredResourceAccess = new List<object>() {
                    new {
                        resourceAppId = "00000003-0000-0000-c000-000000000000",
                        resourceAccess = new List<object>()
                        {
                            new {
                                    id = "37f7f235-527c-4136-accd-4a02d197296e",
                                    type = "Scope"
                                },
                            new {
                                    id = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182",
                                    type = "Scope"
                                }
                        }
                    }
                },
                web = new
                {
                    redirectUris = new List<string>() { $"https://jwt.ms" },
                    implicitGrantSettings = new
                    {
                        enableIdTokenIssuance = true,
                        enableAccessTokenIssuance = true
                    }
                }
            };

            var json = JsonConvert.SerializeObject(iefTestApp);
            var resp = await _http.PostAsync($"https://graph.microsoft.com/beta/applications",
                new StringContent(json, Encoding.UTF8, "application/json"));

            if (!resp.IsSuccessStatusCode)
            {
                string id = await GetAppIdAsync("IEF Test App");
                _actions.Add(new IEFObject()
                {
                    Name = "IEF Test App Registration",
                    Id = id,
                    Status = IEFObject.S.Exists
                });
            }


            if (resp.IsSuccessStatusCode)
            {
                _logger.LogTrace("{0} app created", "iefTestApp");

                string id = await GetAppIdAsync("IEF Test App");
                _actions.Add(new IEFObject()
                {
                    Name = "IEF Test App Registration",
                    Id = id,
                    Status = IEFObject.S.New
                });



                var sp = new
                {
                    accountEnabled = true,
                    appId = _actions.First(kvp => kvp.Name == "IEF Test App Registration").Id,
                    appRoleAssignmentRequired = false,
                    displayName = "IEF Test App",
                };
                resp = await _http.PostAsync($"https://graph.microsoft.com/beta/servicePrincipals",
                    new StringContent(JsonConvert.SerializeObject(sp), Encoding.UTF8, "application/json"));
                if (!resp.IsSuccessStatusCode) throw new Exception(resp.ReasonPhrase);
                //AdminConsentUrl = new Uri($"https://login.microsoftonline.com/{tokens.TenantId}/oauth2/authorize?client_id={appIds.ProxyAppId}&prompt=admin_consent&response_type=code&nonce=defaultNonce");
                _logger.LogTrace("{0} SP created", "IEF Test App");
            }

        }

        private async Task SetupDummyFacebookSecret(bool removeFb)
        {

            if (!_keys.Contains($"B2C_1A_FacebookSecret"))
            {
                var fbKeySetResp = await _http.PostAsync("https://graph.microsoft.com/beta/trustFramework/keySets",
                new StringContent(JsonConvert.SerializeObject(new { id = "FacebookSecret" }), Encoding.UTF8, "application/json"));


                var fbKeyGenerateResp = await _http.PostAsync("https://graph.microsoft.com/beta/trustFramework/keySets/B2C_1A_FacebookSecret/uploadSecret",
                new StringContent(JsonConvert.SerializeObject(new { use = "sig", k = "secret", nbf = 1607626546, exp = 4132148146 }), Encoding.UTF8, "application/json"));

                if (fbKeyGenerateResp.IsSuccessStatusCode)
                {
                    _actions.Add(new IEFObject()
                    {
                        Name = "Facebook secret",
                        Id = "B2C_FacebookSecret",
                        Status = IEFObject.S.Uploaded
                    });

                }
            }
            if (_keys.Contains($"B2C_1A_FacebookSecret") & (!removeFb))
            {
                _actions.Add(new IEFObject()
                {
                    Name = "Facebook secret",
                    Id = "B2C_FacebookSecret",
                    Status = IEFObject.S.Exists
                });

            }

        }

        private List<string> _keys;
        private async Task SetupKeysAsync()
        {
            await CreateKeyIfNotExistsAsync("TokenSigningKeyContainer", "sig");
            await CreateKeyIfNotExistsAsync("TokenEncryptionKeyContainer", "enc");
        }
        private async Task CreateKeyIfNotExistsAsync(string name, string use)
        {
            var keySetupState = new IEFObject() { Name = name, Status = IEFObject.S.NotFound };
            _actions.Add(keySetupState);
            if (_keys == null)
            {
                var resp = await _http.GetStringAsync("https://graph.microsoft.com/beta/trustFramework/keySets");
                var keys = (JArray)JObject.Parse(resp)["value"];
                _keys = keys.Select(k => k["id"].Value<string>()).ToList();
            }
            var kName = $"B2C_1A_{name}";
            if (_keys.Contains($"B2C_1A_{name}"))
            {
                keySetupState.Status = IEFObject.S.Exists;
                if (_readOnly) return;
            } else {
                if (_readOnly) return;
                var httpResp = await _http.PostAsync("https://graph.microsoft.com/beta/trustFramework/keySets",
                    new StringContent(JsonConvert.SerializeObject(new { id = name }), Encoding.UTF8, "application/json"));
                if (httpResp.IsSuccessStatusCode)
                {
                    var keyset = await httpResp.Content.ReadAsStringAsync();
                    var id = JObject.Parse(keyset)["id"].Value<string>();
                    var key = new
                    {
                        use,
                        kty = "RSA"
                    };
                    httpResp = await _http.PostAsync($"https://graph.microsoft.com/beta/trustFramework/keySets/{id}/generateKey",
                        new StringContent(JsonConvert.SerializeObject(key), Encoding.UTF8, "application/json"));
                    if (!httpResp.IsSuccessStatusCode)
                    {
                        await _http.DeleteAsync($"https://graph.microsoft.com/beta/trustFramework/keySets/{id}");
                        throw new Exception(httpResp.ReasonPhrase);
                    }
                    keySetupState.Status = IEFObject.S.New;
                }
                else
                    throw new Exception(httpResp.ReasonPhrase);
            }





        }
        private async Task<string> GetAppIdAsync(string name, bool getObjectId = false)
        {
            var json = await _http.GetStringAsync($"https://graph.microsoft.com/beta/applications?$filter=startsWith(displayName,\'{name}\')");
            var value = (JArray)JObject.Parse(json)["value"];
            //TODO: what if someone created several apps?
            if (value.Count > 0)
            {
                if (getObjectId)
                    return ((JObject)value.First())["id"].Value<string>();
                else
                    return ((JObject)value.First())["appId"].Value<string>();
            }
            return String.Empty;
        }
    }

    public class IEFObject
    {
        public enum S { New, Exists, NotFound, Uploaded, Skipped, Failed }
        public string Name;
        public string Id;
        public S Status;
        public string Reason;
    }
}
